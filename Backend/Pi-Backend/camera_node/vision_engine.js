/**
 * ==============================================================================
 * Smart Shopping Cart - Edge Vision Engine (Browser-Native AI & Centroid Tracker)
 * Platform: Chrome on Android (CAM_LEFT / CAM_RIGHT) & Desktop Localhost
 * Hardware Acceleration: WebGPU -> WebGL -> WASM -> Motion Fallback
 * Latency Target: >= 20 FPS browser inference, <300ms edge reconciliation
 * ==============================================================================
 */

(function () {
  "use strict";

  // --- Configuration Constants ---
  const API_ENDPOINT = "http://localhost:5000/api/vision-event";
  const FRAME_WIDTH = 640;
  const FRAME_HEIGHT = 480;
  const MODEL_INPUT_SIZE = 640;
  const MAX_TRACK_DISTANCE = 90; // Pixels
  const MAX_LOST_FRAMES = 12;
  const COOLDOWN_MS = 1500; // Anti-chatter cooldown per object trajectory

  // COCO Classes subset
  const COCO_CLASSES = [
    "person", "bicycle", "car", "motorcycle", "airplane", "bus", "train", "truck", "boat",
    "traffic light", "fire hydrant", "stop sign", "parking meter", "bench", "bird", "cat",
    "dog", "horse", "sheep", "cow", "elephant", "bear", "zebra", "giraffe", "backpack",
    "umbrella", "handbag", "tie", "suitcase", "frisbee", "skis", "snowboard", "sports ball",
    "kite", "baseball bat", "baseball glove", "skateboard", "surfboard", "tennis racket",
    "bottle", "wine glass", "cup", "fork", "knife", "spoon", "bowl", "banana", "apple",
    "sandwich", "orange", "broccoli", "carrot", "hot dog", "pizza", "donut", "cake", "chair",
    "couch", "potted plant", "bed", "dining table", "toilet", "tv", "laptop", "mouse",
    "remote", "keyboard", "cell phone", "microwave", "oven", "toaster", "sink", "refrigerator",
    "book", "clock", "vase", "scissors", "teddy bear", "hair drier", "toothbrush"
  ];

  // --- State Variables ---
  let cameraId = "CAM_LEFT";
  let yGate = 240; // Default 50% of 480 height
  let confThreshold = 0.40;
  let iouThreshold = 0.45;
  let invertDirection = false; // Normal: top-to-bottom = DROP IN

  let ortSession = null;
  let activeProvider = "INIT";
  let isModelRunning = false;
  let nextTrackId = 1;
  const trackedObjects = new Map();

  // Camera & Simulation State
  let isCameraActive = false;
  let isSimulationMode = false;
  let simItem = { x: 280, y: 40, vy: 3.2, w: 80, h: 110, label: "item", direction: 1 };

  // Motion fallback state
  let prevFrameGray = null;
  let offscreenCanvas = null;
  let offscreenCtx = null;

  // Telemetry state
  let frameCount = 0;
  let lastFpsUpdateTime = performance.now();
  let currentFps = 0;
  let currentLatency = 0;
  let totalDispatchedEvents = 0;

  // DOM Elements
  const videoElem = document.getElementById("webcam-video");
  const canvasElem = document.getElementById("vision-canvas");
  const canvasCtx = canvasElem.getContext("2d");
  const viewportBox = document.getElementById("viewport-box");

  // Telemetry & Controls DOM
  const valFps = document.getElementById("val-fps");
  const valProvider = document.getElementById("val-provider");
  const valLatency = document.getElementById("val-latency");
  const valTrackedCount = document.getElementById("val-tracked-count");
  const valModelStatus = document.getElementById("val-model-status");
  const sliderGateY = document.getElementById("slider-gate-y");
  const valGateY = document.getElementById("val-gate-y");
  const sliderConf = document.getElementById("slider-conf");
  const valConfThresh = document.getElementById("val-conf-thresh");
  const toggleInvertDirection = document.getElementById("toggle-invert-direction");
  const btnRoleLeft = document.getElementById("btn-role-left");
  const btnRoleRight = document.getElementById("btn-role-right");
  const btnManualIn = document.getElementById("btn-manual-in");
  const btnManualOut = document.getElementById("btn-manual-out");
  const btnResetTracker = document.getElementById("btn-reset-tracker");
  const eventHistoryList = document.getElementById("event-history-list");
  const eventStats = document.getElementById("event-stats");

  // Camera Status Overlay DOM
  const cameraOverlay = document.getElementById("camera-status-overlay");
  const cameraSpinner = document.getElementById("camera-spinner");
  const cameraStatusTitle = document.getElementById("camera-status-title");
  const cameraStatusSub = document.getElementById("camera-status-sub");
  const cameraActionBtns = document.getElementById("camera-action-btns");
  const btnCameraRetry = document.getElementById("btn-camera-retry");
  const btnCameraSim = document.getElementById("btn-camera-sim");

  // ============================================================================
  // Configuration & Event Bindings
  // ============================================================================

  function initConfiguration() {
    // Determine Camera Role from URL query params or localStorage
    const urlParams = new URLSearchParams(window.location.search);
    const paramCam = urlParams.get("cam");
    if (paramCam && (paramCam === "CAM_LEFT" || paramCam === "CAM_RIGHT")) {
      cameraId = paramCam;
    } else {
      const stored = localStorage.getItem("cart_camera_id");
      if (stored === "CAM_LEFT" || stored === "CAM_RIGHT") {
        cameraId = stored;
      }
    }
    updateRoleUI();

    // Setup offscreen canvas for preprocessing
    offscreenCanvas = document.createElement("canvas");
    offscreenCanvas.width = MODEL_INPUT_SIZE;
    offscreenCanvas.height = MODEL_INPUT_SIZE;
    offscreenCtx = offscreenCanvas.getContext("2d", { willReadFrequently: true });

    // Slider Listeners
    sliderGateY.addEventListener("input", function (e) {
      yGate = parseInt(e.target.value, 10);
      valGateY.textContent = yGate + " px (" + Math.round((yGate / FRAME_HEIGHT) * 100) + "%)";
    });

    sliderConf.addEventListener("input", function (e) {
      confThreshold = parseInt(e.target.value, 10) / 100;
      valConfThresh.textContent = Math.round(confThreshold * 100) + "%";
    });

    toggleInvertDirection.addEventListener("change", function (e) {
      invertDirection = e.target.checked;
    });

    btnRoleLeft.addEventListener("click", function () { setRole("CAM_LEFT"); });
    btnRoleRight.addEventListener("click", function () { setRole("CAM_RIGHT"); });

    btnManualIn.addEventListener("click", function () {
      dispatchReactionEvent("CROSS_IN", "manual_test");
    });
    btnManualOut.addEventListener("click", function () {
      dispatchReactionEvent("CROSS_OUT", "manual_test");
    });
    btnResetTracker.addEventListener("click", function () {
      trackedObjects.clear();
      logEventEntry("RESET", "All tracked trajectories cleared", true);
    });

    // Camera Overlay Buttons
    if (btnCameraRetry) {
      btnCameraRetry.addEventListener("click", function () {
        cameraActionBtns.style.display = "none";
        cameraSpinner.style.display = "block";
        cameraStatusTitle.textContent = "Retrying Camera...";
        cameraStatusSub.className = "status-subtitle";
        cameraStatusSub.textContent = "Requesting video stream from media device...";
        startWebcam();
      });
    }

    if (btnCameraSim) {
      btnCameraSim.addEventListener("click", function () {
        startSimulationMode("User requested simulation feed");
      });
    }
  }

  function setRole(role) {
    cameraId = role;
    localStorage.setItem("cart_camera_id", role);
    updateRoleUI();
  }

  function updateRoleUI() {
    if (cameraId === "CAM_LEFT") {
      btnRoleLeft.classList.add("active");
      btnRoleRight.classList.remove("active");
    } else {
      btnRoleRight.classList.add("active");
      btnRoleLeft.classList.remove("active");
    }
  }

  // ============================================================================
  // Adaptive Multi-Stage Camera Capture
  // ============================================================================

  async function startWebcam() {
    console.log("[Camera] Initiating adaptive camera detection...");

    // 1. Check for Secure Context
    if (window.isSecureContext === false && location.hostname !== "localhost" && location.hostname !== "127.0.0.1") {
      const errMsg = "Insecure Context: Browsers restrict camera access to HTTPS or localhost origins.";
      console.error("[Camera]", errMsg);
      showCameraError("SecurityError", errMsg);
      startSimulationMode("Insecure context fallback");
      return;
    }

    // 2. Check navigator.mediaDevices support
    if (!navigator.mediaDevices || !navigator.mediaDevices.getUserMedia) {
      const errMsg = "navigator.mediaDevices.getUserMedia API not supported on this browser.";
      console.error("[Camera]", errMsg);
      showCameraError("NotSupportedError", errMsg);
      startSimulationMode("Missing mediaDevices API");
      return;
    }

    // 3. Adaptive Constraints Ladder
    const constraintLadder = [
      {
        name: "Mobile Rear Camera (640x480 @ 30FPS)",
        constraints: {
          audio: false,
          video: {
            facingMode: { ideal: "environment" },
            width: { ideal: FRAME_WIDTH },
            height: { ideal: FRAME_HEIGHT },
            frameRate: { ideal: 30 }
          }
        }
      },
      {
        name: "Desktop Preferred (640x480)",
        constraints: {
          audio: false,
          video: {
            width: { ideal: FRAME_WIDTH },
            height: { ideal: FRAME_HEIGHT }
          }
        }
      },
      {
        name: "Standard Front / User Camera",
        constraints: {
          audio: false,
          video: { facingMode: "user" }
        }
      },
      {
        name: "Any Generic Video Input",
        constraints: { audio: false, video: true }
      }
    ];

    let stream = null;
    let lastError = null;

    for (const step of constraintLadder) {
      try {
        console.log(`[Camera] Trying constraint: ${step.name}`);
        cameraStatusSub.textContent = `Attempting: ${step.name}...`;
        stream = await navigator.mediaDevices.getUserMedia(step.constraints);
        if (stream) {
          console.log(`[Camera] Successfully acquired stream with: ${step.name}`);
          break;
        }
      } catch (err) {
        console.warn(`[Camera] Constraint '${step.name}' failed: ${err.name} - ${err.message}`);
        lastError = err;
      }
    }

    // 4. Handle Successful Stream Attachment
    if (stream) {
      try {
        videoElem.muted = true;
        videoElem.playsInline = true;
        videoElem.autoplay = true;
        videoElem.setAttribute("playsinline", "");
        videoElem.setAttribute("muted", "");
        videoElem.setAttribute("autoplay", "");
        videoElem.srcObject = stream;

        // Ensure video is actively playing
        await videoElem.play().catch(function (pErr) {
          console.warn("[Camera] Play caught:", pErr);
        });

        // Wait for readyState >= 2 (HAVE_CURRENT_DATA)
        if (videoElem.readyState < 2) {
          await new Promise(function (resolve) {
            const onDone = function () {
              videoElem.removeEventListener("loadeddata", onDone);
              videoElem.removeEventListener("loadedmetadata", onDone);
              resolve();
            };
            videoElem.addEventListener("loadeddata", onDone);
            videoElem.addEventListener("loadedmetadata", onDone);
            setTimeout(onDone, 2000);
          });
        }

        isCameraActive = true;
        isSimulationMode = false;
        cameraOverlay.classList.add("hidden");
        console.log("[Camera] Video feed active and rendering to canvas.");
        return;
      } catch (attachErr) {
        console.error("[Camera] Error binding video stream:", attachErr);
        lastError = attachErr;
      }
    }

    // 5. If all hardware options failed, show visual error & engage simulation feed
    const errName = lastError ? lastError.name : "NotFoundError";
    let userMsg = lastError ? lastError.message : "No camera detected";

    if (errName === "NotAllowedError" || errName === "PermissionDeniedError") {
      userMsg = "Camera access denied. Please click the camera icon in your address bar to allow permissions.";
    } else if (errName === "NotFoundError" || errName === "DevicesNotFoundError") {
      userMsg = "No webcam or camera device found on this system.";
    } else if (errName === "NotReadableError" || errName === "TrackStartError") {
      userMsg = "Webcam is already in use by another application.";
    } else if (errName === "OverconstrainedError") {
      userMsg = "Webcam cannot fulfill 640x480 resolution.";
    }

    showCameraError(errName, userMsg);
    startSimulationMode(`Hardware fallback (${errName})`);
  }

  function showCameraError(errName, message) {
    cameraSpinner.style.display = "none";
    cameraStatusTitle.textContent = "Camera Feed Unavailable";
    cameraStatusSub.className = "status-subtitle error-text";
    cameraStatusSub.textContent = `${errName}: ${message}`;
    if (cameraActionBtns) {
      cameraActionBtns.style.display = "flex";
    }
  }

  function startSimulationMode(reason) {
    console.info(`[Simulation Feed] Starting synthetic video feed: ${reason}`);
    isSimulationMode = true;
    isCameraActive = false;
    valModelStatus.textContent = "Simulation Feed (Active)";

    // Automatically hide error overlay after 2 seconds so user sees the simulated feed
    setTimeout(function () {
      if (cameraOverlay) {
        cameraOverlay.classList.add("hidden");
      }
    }, 2000);
  }

  // ============================================================================
  // Synthetic Desktop Simulation Feed (Allows testing without a physical webcam)
  // ============================================================================

  function renderSimulationBackground() {
    // 1. Draw synthetic perspective shopping trolley basket entrance
    const grad = canvasCtx.createLinearGradient(0, 0, 0, FRAME_HEIGHT);
    grad.addColorStop(0, "#070c14");
    grad.addColorStop(0.5, "#0d1522");
    grad.addColorStop(1, "#121b2a");
    canvasCtx.fillStyle = grad;
    canvasCtx.fillRect(0, 0, FRAME_WIDTH, FRAME_HEIGHT);

    // Basket grid lines
    canvasCtx.strokeStyle = "rgba(0, 242, 254, 0.08)";
    canvasCtx.lineWidth = 1;
    for (let x = 40; x < FRAME_WIDTH; x += 40) {
      canvasCtx.beginPath();
      canvasCtx.moveTo(x, 0);
      canvasCtx.lineTo(x, FRAME_HEIGHT);
      canvasCtx.stroke();
    }
    for (let y = 30; y < FRAME_HEIGHT; y += 30) {
      canvasCtx.beginPath();
      canvasCtx.moveTo(0, y);
      canvasCtx.lineTo(FRAME_WIDTH, y);
      canvasCtx.stroke();
    }

    // Top Header Badge
    canvasCtx.font = "bold 11px monospace";
    canvasCtx.fillStyle = "rgba(255, 234, 0, 0.7)";
    canvasCtx.fillText("● DESKTOP SIMULATION MODE [Moving Test Product]", 14, 24);
  }

  function updateSimulationItem() {
    // Move item along Y axis across the virtual gate
    simItem.y += simItem.vy * simItem.direction;

    // Bounce / loop item
    if (simItem.y > FRAME_HEIGHT - 60) {
      simItem.y = 40; // Loop back to top to simulate next item drop
    }

    const x1 = simItem.x;
    const y1 = simItem.y;
    const x2 = simItem.x + simItem.w;
    const y2 = simItem.y + simItem.h;

    // Draw realistic test item box on canvas
    canvasCtx.save();
    canvasCtx.fillStyle = "rgba(79, 172, 254, 0.25)";
    canvasCtx.strokeStyle = "#4facfe";
    canvasCtx.lineWidth = 2;
    canvasCtx.fillRect(x1, y1, simItem.w, simItem.h);
    canvasCtx.strokeRect(x1, y1, simItem.w, simItem.h);

    // Item label
    canvasCtx.fillStyle = "#fff";
    canvasCtx.font = "bold 12px sans-serif";
    canvasCtx.fillText("Organic Milk 1L", x1 + 6, y1 + 22);
    canvasCtx.font = "10px monospace";
    canvasCtx.fillStyle = "rgba(255,255,255,0.7)";
    canvasCtx.fillText("EAN: 8901030383848", x1 + 6, y1 + 38);
    canvasCtx.restore();

    return [{
      x1: x1,
      y1: y1,
      x2: x2,
      y2: y2,
      cx: (x1 + x2) / 2,
      cy: (y1 + y2) / 2,
      score: 0.94,
      classLabel: "bottle"
    }];
  }

  // ============================================================================
  // ONNX Runtime Web Model Loading & Fallback
  // ============================================================================

  async function initInferenceEngine() {
    if (typeof ort === "undefined") {
      console.warn("[Vision Engine] 'ort' global not found. Entering Motion-Fallback mode.");
      setupMotionFallback("ort not defined");
      return;
    }

    valModelStatus.textContent = "Loading Model...";
    const providers = ["webgpu", "webgl", "wasm"];

    for (const provider of providers) {
      try {
        console.log("[Vision Engine] Attempting ONNX session creation with provider:", provider);
        ortSession = await ort.InferenceSession.create("./models/yolov8n_quantized.onnx", {
          executionProviders: [provider],
          graphOptimizationLevel: "all"
        });
        activeProvider = provider.toUpperCase();
        valProvider.textContent = activeProvider;
        valModelStatus.textContent = "YOLOv8n (" + activeProvider + ")";
        console.log("[Vision Engine] Successfully initialized YOLOv8n ONNX model with:", activeProvider);
        return;
      } catch (err) {
        console.warn("[Vision Engine] Failed provider '" + provider + "':", err.message);
      }
    }

    setupMotionFallback("ONNX binary not ready");
  }

  function setupMotionFallback(reason) {
    activeProvider = "MOTION-FB";
    valProvider.textContent = "FALLBACK";
    valProvider.style.color = "#ffea00";
    valModelStatus.textContent = isSimulationMode ? "Simulation Feed" : "Motion Centroid Tracker";
    console.info("[Vision Engine] Operating in Motion Centroid Fallback mode (" + reason + ").");
  }

  // ============================================================================
  // Preprocessing: 640x480 Canvas -> Normalized Float32 Tensor [1, 3, 640, 640]
  // ============================================================================

  function preprocessFrame() {
    offscreenCtx.fillStyle = "#000000";
    offscreenCtx.fillRect(0, 0, MODEL_INPUT_SIZE, MODEL_INPUT_SIZE);

    const padTop = 80;
    if (isCameraActive) {
      offscreenCtx.drawImage(videoElem, 0, 0, FRAME_WIDTH, FRAME_HEIGHT, 0, padTop, 640, 480);
    } else {
      offscreenCtx.drawImage(canvasElem, 0, 0, FRAME_WIDTH, FRAME_HEIGHT, 0, padTop, 640, 480);
    }

    const imgData = offscreenCtx.getImageData(0, 0, MODEL_INPUT_SIZE, MODEL_INPUT_SIZE);
    const pixels = imgData.data;
    const numPixels = MODEL_INPUT_SIZE * MODEL_INPUT_SIZE;
    const float32Data = new Float32Array(3 * numPixels);

    for (let i = 0; i < numPixels; i++) {
      float32Data[i] = pixels[i * 4] / 255.0;
      float32Data[numPixels + i] = pixels[i * 4 + 1] / 255.0;
      float32Data[2 * numPixels + i] = pixels[i * 4 + 2] / 255.0;
    }

    return new ort.Tensor("float32", float32Data, [1, 3, MODEL_INPUT_SIZE, MODEL_INPUT_SIZE]);
  }

  // ============================================================================
  // Postprocessing: YOLOv8 Output [1, 84, 8400] Parsing & NMS
  // ============================================================================

  function postprocessYOLOv8(outputTensor) {
    const data = outputTensor.data;
    const numAnchors = 8400;
    const numClasses = 80;
    const candidates = [];
    const padTop = 80;

    for (let i = 0; i < numAnchors; i++) {
      let maxScore = -Infinity;
      let maxClassId = -1;

      for (let c = 0; c < numClasses; c++) {
        const score = data[(4 + c) * numAnchors + i];
        if (score > maxScore) {
          maxScore = score;
          maxClassId = c;
        }
      }

      if (maxScore >= confThreshold) {
        const cx = data[0 * numAnchors + i];
        const cy = data[1 * numAnchors + i];
        const w = data[2 * numAnchors + i];
        const h = data[3 * numAnchors + i];

        const realCy = cy - padTop;
        const x1 = Math.max(0, cx - w / 2);
        const y1 = Math.max(0, realCy - h / 2);
        const x2 = Math.min(FRAME_WIDTH, cx + w / 2);
        const y2 = Math.min(FRAME_HEIGHT, realCy + h / 2);

        candidates.push({
          x1: x1,
          y1: y1,
          x2: x2,
          y2: y2,
          cx: (x1 + x2) / 2,
          cy: (y1 + y2) / 2,
          score: maxScore,
          classLabel: COCO_CLASSES[maxClassId] || "item"
        });
      }
    }

    return applyNMS(candidates, iouThreshold);
  }

  function applyNMS(boxes, threshold) {
    boxes.sort((a, b) => b.score - a.score);
    const selected = [];
    const active = new Array(boxes.length).fill(true);

    for (let i = 0; i < boxes.length; i++) {
      if (!active[i]) continue;
      selected.push(boxes[i]);

      for (let j = i + 1; j < boxes.length; j++) {
        if (!active[j]) continue;
        if (computeIoU(boxes[i], boxes[j]) > threshold) {
          active[j] = false;
        }
      }
    }
    return selected;
  }

  function computeIoU(b1, b2) {
    const xLeft = Math.max(b1.x1, b2.x1);
    const yTop = Math.max(b1.y1, b2.y1);
    const xRight = Math.min(b1.x2, b2.x2);
    const yBottom = Math.min(b1.y2, b2.y2);

    if (xRight < xLeft || yBottom < yTop) return 0.0;

    const intersectionArea = (xRight - xLeft) * (yBottom - yTop);
    const area1 = (b1.x2 - b1.x1) * (b1.y2 - b1.y1);
    const area2 = (b2.x2 - b2.x1) * (b2.y2 - b2.y1);
    const unionArea = area1 + area2 - intersectionArea;

    return unionArea > 0 ? intersectionArea / unionArea : 0.0;
  }

  // ============================================================================
  // High-Speed Frame-Differencing Motion Centroid Fallback
  // ============================================================================

  function detectMotionCentroids() {
    const dw = 160;
    const dh = 120;

    offscreenCanvas.width = dw;
    offscreenCanvas.height = dh;
    offscreenCtx.drawImage(isCameraActive ? videoElem : canvasElem, 0, 0, dw, dh);
    const frame = offscreenCtx.getImageData(0, 0, dw, dh);
    const data = frame.data;
    const gray = new Uint8Array(dw * dh);

    for (let i = 0; i < gray.length; i++) {
      gray[i] = (data[i * 4] * 0.299 + data[i * 4 + 1] * 0.587 + data[i * 4 + 2] * 0.114) | 0;
    }

    if (!prevFrameGray) {
      prevFrameGray = gray;
      return [];
    }

    let minX = dw, maxX = 0, minY = dh, maxY = 0;
    let sumX = 0, sumY = 0, motionCount = 0;
    const diffThreshold = 28;

    for (let y = 0; y < dh; y++) {
      for (let x = 0; x < dw; x++) {
        const idx = y * dw + x;
        const diff = Math.abs(gray[idx] - prevFrameGray[idx]);
        if (diff > diffThreshold) {
          motionCount++;
          sumX += x;
          sumY += y;
          if (x < minX) minX = x;
          if (x > maxX) maxX = x;
          if (y < minY) minY = y;
          if (y > maxY) maxY = y;
        }
      }
    }

    prevFrameGray = gray;

    if (motionCount > 80 && maxX > minX && maxY > minY) {
      const scaleX = FRAME_WIDTH / dw;
      const scaleY = FRAME_HEIGHT / dh;

      return [{
        x1: Math.max(0, minX * scaleX - 10),
        y1: Math.max(0, minY * scaleY - 10),
        x2: Math.min(FRAME_WIDTH, maxX * scaleX + 10),
        y2: Math.min(FRAME_HEIGHT, maxY * scaleY + 10),
        cx: (sumX / motionCount) * scaleX,
        cy: (sumY / motionCount) * scaleY,
        score: Math.min(0.99, motionCount / 400),
        classLabel: "item"
      }];
    }

    return [];
  }

  // ============================================================================
  // Virtual Gate Centroid Tracker & Spatial Trajectory Engine
  // ============================================================================

  function updateCentroidTracker(detections) {
    const now = performance.now();
    const matchedTrackIds = new Set();

    for (const det of detections) {
      let bestDist = Infinity;
      let bestId = null;

      for (const [id, obj] of trackedObjects.entries()) {
        if (matchedTrackIds.has(id)) continue;
        const dist = Math.hypot(det.cx - obj.cx, det.cy - obj.cy);
        if (dist < MAX_TRACK_DISTANCE && dist < bestDist) {
          bestDist = dist;
          bestId = id;
        }
      }

      if (bestId !== null) {
        matchedTrackIds.add(bestId);
        const obj = trackedObjects.get(bestId);
        obj.prev_y = obj.cy;
        obj.prev_x = obj.cx;
        obj.cx = det.cx;
        obj.cy = det.cy;
        obj.x1 = det.x1;
        obj.y1 = det.y1;
        obj.x2 = det.x2;
        obj.y2 = det.y2;
        obj.score = det.score;
        obj.classLabel = det.classLabel;
        obj.lostFrames = 0;
        obj.history.push({ x: det.cx, y: det.cy, t: now });
        if (obj.history.length > 12) obj.history.shift();

        evaluateCrossing(obj, now);
      } else {
        const newId = nextTrackId++;
        const newObj = {
          id: newId,
          cx: det.cx,
          cy: det.cy,
          prev_x: det.cx,
          prev_y: det.cy,
          x1: det.x1,
          y1: det.y1,
          x2: det.x2,
          y2: det.y2,
          score: det.score,
          classLabel: det.classLabel,
          lostFrames: 0,
          triggered: false,
          lastTriggerTime: 0,
          history: [{ x: det.cx, y: det.cy, t: now }]
        };
        trackedObjects.set(newId, newObj);
        matchedTrackIds.add(newId);
      }
    }

    for (const [id, obj] of trackedObjects.entries()) {
      if (!matchedTrackIds.has(id)) {
        obj.lostFrames++;
        if (obj.lostFrames > MAX_LOST_FRAMES) {
          trackedObjects.delete(id);
        }
      }
    }

    valTrackedCount.textContent = trackedObjects.size;
  }

  function evaluateCrossing(obj, now) {
    if (obj.triggered && (now - obj.lastTriggerTime < COOLDOWN_MS)) {
      return;
    }

    const yPrev = obj.prev_y;
    const yCurr = obj.cy;

    let isCrossingIn = false;
    let isCrossingOut = false;

    if (!invertDirection) {
      isCrossingIn = (yPrev < yGate && yCurr >= yGate);
      isCrossingOut = (yPrev > yGate && yCurr <= yGate);
    } else {
      isCrossingIn = (yPrev > yGate && yCurr <= yGate);
      isCrossingOut = (yPrev < yGate && yCurr >= yGate);
    }

    if (isCrossingIn) {
      obj.triggered = true;
      obj.lastTriggerTime = now;
      triggerVisualFlash("flash-in");
      dispatchReactionEvent("CROSS_IN", obj.classLabel);
    } else if (isCrossingOut) {
      obj.triggered = true;
      obj.lastTriggerTime = now;
      triggerVisualFlash("flash-out");
      dispatchReactionEvent("CROSS_OUT", obj.classLabel);
    }
  }

  function triggerVisualFlash(cssClass) {
    viewportBox.classList.remove("flash-in", "flash-out");
    void viewportBox.offsetWidth;
    viewportBox.classList.add(cssClass);
  }

  // ============================================================================
  // USB Reaction Dispatcher: POST http://localhost:5000/api/vision-event
  // ============================================================================

  function dispatchReactionEvent(eventType, detectedClass) {
    totalDispatchedEvents++;
    eventStats.textContent = totalDispatchedEvents + " Events";

    const payload = {
      camera_id: cameraId,
      event: eventType,
      detected_class: detectedClass || "item",
      timestamp: parseFloat((Date.now() / 1000).toFixed(3))
    };

    console.info("[USB Dispatch] Dispatching reaction event:", payload);

    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), 1000);

    fetch(API_ENDPOINT, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(payload),
      signal: controller.signal
    })
      .then(function (response) {
        clearTimeout(timeoutId);
        if (response.ok) {
          logEventEntry(eventType, detectedClass, true, response.status);
        } else {
          logEventEntry(eventType, detectedClass, false, "HTTP " + response.status);
        }
      })
      .catch(function (err) {
        clearTimeout(timeoutId);
        console.warn("[USB Dispatch] Event dispatch note:", err.message);
        logEventEntry(eventType, detectedClass, false, "ERR / OFFLINE");
      });
  }

  function logEventEntry(eventType, className, success, note) {
    const li = document.createElement("li");
    li.className = "event-item " + (eventType === "CROSS_IN" ? "in" : (eventType === "CROSS_OUT" ? "out" : ""));

    const d = new Date();
    const timeStr = d.toTimeString().split(" ")[0] + "." + String(d.getMilliseconds()).padStart(3, "0");

    li.innerHTML =
      "<div>" +
      "<span class='event-name'>[" + cameraId + "] " + eventType + " (" + className + ")</span>" +
      "<span class='event-meta'>" + timeStr + "</span>" +
      "</div>" +
      "<span class='event-status " + (success ? "" : "error") + "'>" + (note || (success ? "200 OK" : "FAILED")) + "</span>";

    eventHistoryList.insertBefore(li, eventHistoryList.firstChild);

    while (eventHistoryList.children.length > 8) {
      eventHistoryList.removeChild(eventHistoryList.lastChild);
    }
  }

  // ============================================================================
  // Canvas Visualization & HUD Rendering
  // ============================================================================

  function renderVisuals(detections) {
    // 1. Draw source video if active
    if (isCameraActive) {
      canvasCtx.drawImage(videoElem, 0, 0, FRAME_WIDTH, FRAME_HEIGHT);
    }

    // 2. Draw Virtual Gate Threshold Line (Y_gate)
    canvasCtx.save();
    canvasCtx.lineWidth = 3;
    canvasCtx.strokeStyle = "#00f2fe";
    canvasCtx.setLineDash([10, 6]);
    canvasCtx.beginPath();
    canvasCtx.moveTo(0, yGate);
    canvasCtx.lineTo(FRAME_WIDTH, yGate);
    canvasCtx.stroke();

    canvasCtx.shadowColor = "#00f2fe";
    canvasCtx.shadowBlur = 10;
    canvasCtx.font = "bold 12px monospace";
    canvasCtx.fillStyle = "#00f2fe";
    const dirArrow = invertDirection ? " ▲ (INWARD DROP)" : " ▼ (INWARD DROP)";
    canvasCtx.fillText("VIRTUAL GATE [Y=" + yGate + "]" + dirArrow, 14, yGate - 8);
    canvasCtx.restore();

    // 3. Render Tracked Objects, Trails, Centroids, and Bounding Boxes
    for (const [id, obj] of trackedObjects.entries()) {
      if (obj.history.length > 1) {
        canvasCtx.save();
        canvasCtx.lineWidth = 3;
        canvasCtx.strokeStyle = obj.triggered ? "#00e676" : "#4facfe";
        canvasCtx.beginPath();
        canvasCtx.moveTo(obj.history[0].x, obj.history[0].y);
        for (let i = 1; i < obj.history.length; i++) {
          canvasCtx.lineTo(obj.history[i].x, obj.history[i].y);
        }
        canvasCtx.stroke();
        canvasCtx.restore();
      }

      const boxW = obj.x2 - obj.x1;
      const boxH = obj.y2 - obj.y1;
      canvasCtx.save();
      canvasCtx.lineWidth = 2;
      canvasCtx.strokeStyle = obj.triggered ? "#00e676" : "#00f2fe";
      canvasCtx.fillStyle = obj.triggered ? "rgba(0, 230, 118, 0.12)" : "rgba(0, 242, 254, 0.08)";
      canvasCtx.fillRect(obj.x1, obj.y1, boxW, boxH);
      canvasCtx.strokeRect(obj.x1, obj.y1, boxW, boxH);

      const label = "#" + obj.id + " " + obj.classLabel + " (" + Math.round(obj.score * 100) + "%)";
      canvasCtx.font = "bold 11px sans-serif";
      const textWidth = canvasCtx.measureText(label).width;
      canvasCtx.fillStyle = obj.triggered ? "#00e676" : "#00f2fe";
      canvasCtx.fillRect(obj.x1, Math.max(0, obj.y1 - 18), textWidth + 8, 18);
      canvasCtx.fillStyle = "#050b14";
      canvasCtx.fillText(label, obj.x1 + 4, Math.max(12, obj.y1 - 5));

      canvasCtx.beginPath();
      canvasCtx.arc(obj.cx, obj.cy, 5, 0, 2 * Math.PI);
      canvasCtx.fillStyle = "#ffea00";
      canvasCtx.fill();
      canvasCtx.lineWidth = 2;
      canvasCtx.strokeStyle = "#ffffff";
      canvasCtx.stroke();
      canvasCtx.restore();
    }
  }

  // ============================================================================
  // Main Non-blocking Vision Pipeline Loop (requestAnimationFrame)
  // ============================================================================

  async function visionPipelineLoop() {
    const t0 = performance.now();
    let detections = [];

    if (isCameraActive && videoElem.readyState >= 2) {
      try {
        if (ortSession && !isModelRunning) {
          isModelRunning = true;
          const inputTensor = preprocessFrame();
          const results = await ortSession.run({ [ortSession.inputNames[0]]: inputTensor });
          const outputTensor = results[ortSession.outputNames[0]];
          detections = postprocessYOLOv8(outputTensor);
          isModelRunning = false;
        } else if (!ortSession) {
          detections = detectMotionCentroids();
        }
      } catch (err) {
        console.error("[Vision Engine] Pipeline cycle error:", err);
        isModelRunning = false;
        detections = detectMotionCentroids();
      }

      updateCentroidTracker(detections);
      renderVisuals(detections);

    } else if (isSimulationMode) {
      // Synthetic Simulation Pipeline
      renderSimulationBackground();
      detections = updateSimulationItem();
      updateCentroidTracker(detections);
      renderVisuals(detections);
    }

    currentLatency = Math.round(performance.now() - t0);
    valLatency.textContent = currentLatency + " ms";

    frameCount++;
    const now = performance.now();
    if (now - lastFpsUpdateTime >= 500) {
      currentFps = Math.round((frameCount * 1000) / (now - lastFpsUpdateTime));
      frameCount = 0;
      lastFpsUpdateTime = now;

      valFps.textContent = currentFps;
      valFps.className = "telemetry-val " + (currentFps >= 20 ? "fps-optimal" : (currentFps >= 15 ? "fps-medium" : "fps-low"));
    }

    requestAnimationFrame(visionPipelineLoop);
  }

  // ============================================================================
  // Robust Lifecycle App Entry Point (Supports direct and async script injection)
  // ============================================================================

  function boot() {
    console.log("[Vision Node] Booting Edge Vision Application...");
    initConfiguration();
    startWebcam()
      .catch(function (err) {
        console.warn("[Vision Node] Camera boot caught:", err);
      })
      .finally(async function () {
        await initInferenceEngine();
        requestAnimationFrame(visionPipelineLoop);
      });
  }

  if (document.readyState === "loading") {
    window.addEventListener("DOMContentLoaded", boot);
  } else {
    // DOM is already ready (ort.min.js was loaded asynchronously first)
    boot();
  }

})();
