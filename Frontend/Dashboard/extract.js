const fs = require('fs');
const path = 'C:/Users/Sunny Kumar Sah/.gemini/antigravity-ide/brain/e1994faf-b26c-4fe5-afb3-b92f678bffad/.system_generated/steps/38/content.md';
let content = fs.readFileSync(path, 'utf8');

// Extract between <body> and <script>
let start = content.indexOf('<body');
let end = content.lastIndexOf('<script');
if (start !== -1 && end !== -1) {
    let bodyContent = content.substring(start, end);
    // Remove the <body> tag itself
    bodyContent = bodyContent.replace(/<body[^>]*>/, '').replace(/<\/body>/, '');
    fs.writeFileSync('C:/Users/Sunny Kumar Sah/OneDrive/Study Materials/Projects/ECS/Ver 1.0/Frontend/smart-trolley/src/app/dashboard/dashboard.html', bodyContent.trim());
    console.log('Extracted successfully');
} else {
    console.log('Failed to extract');
}
