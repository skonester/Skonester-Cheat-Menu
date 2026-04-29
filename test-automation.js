#!/usr/bin/env node

/**
 * Test script for GitHub Issue Automation
 * 
 * This script tests the basic functionality without making actual API calls.
 */

const fs = require('fs');
const path = require('path');

console.log('🧪 Testing GitHub Issue Automation Setup...\n');

// Test 1: Check if required files exist
const requiredFiles = [
  '.github/workflows/issue-automation.yml',
  '.github/ISSUE_TEMPLATE/bug_report.md',
  '.github/ISSUE_TEMPLATE/feature_request.md',
  '.github/ISSUE_TEMPLATE/translation_request.md',
  '.github/issue-automation.json',
  'issue-automation.js',
  'package.json',
  'AUTOMATION-README.md'
];

console.log('📁 Checking required files:');
let allFilesExist = true;

requiredFiles.forEach(file => {
  const filePath = path.join(__dirname, file);
  const exists = fs.existsSync(filePath);
  console.log(`  ${exists ? '✅' : '❌'} ${file}`);
  if (!exists) allFilesExist = false;
});

// Test 2: Validate JSON configuration
console.log('\n⚙️  Validating configuration:');
try {
  const configPath = path.join(__dirname, '.github', 'issue-automation.json');
  const configData = fs.readFileSync(configPath, 'utf8');
  const config = JSON.parse(configData);
  console.log('  ✅ Configuration JSON is valid');
  
  // Check required fields
  const requiredConfigSections = ['autoLabel', 'welcomeMessage'];
  requiredConfigSections.forEach(section => {
    if (config[section]) {
      console.log(`  ✅ ${section} configuration present`);
    } else {
      console.log(`  ⚠️  ${section} configuration missing`);
    }
  });
} catch (error) {
  console.log(`  ❌ Configuration error: ${error.message}`);
  allFilesExist = false;
}

// Test 3: Validate YAML workflow
console.log('\n⚡ Validating GitHub Actions workflow:');
try {
  const workflowPath = path.join(__dirname, '.github', 'workflows', 'issue-automation.yml');
  const workflowContent = fs.readFileSync(workflowPath, 'utf8');
  
  // Basic YAML structure checks
  const hasName = workflowContent.includes('name:');
  const hasOnSection = workflowContent.includes('on:');
  const hasJobsSection = workflowContent.includes('jobs:');
  
  if (hasName && hasOnSection && hasJobsSection) {
    console.log('  ✅ Workflow YAML structure is valid');
  } else {
    console.log('  ❌ Workflow YAML missing required sections');
    allFilesExist = false;
  }
} catch (error) {
  console.log(`  ❌ Workflow error: ${error.message}`);
  allFilesExist = false;
}

// Test 4: Validate package.json
console.log('\n📦 Validating package.json:');
try {
  const packagePath = path.join(__dirname, 'package.json');
  const packageData = fs.readFileSync(packagePath, 'utf8');
  const pkg = JSON.parse(packageData);
  
  const requiredFields = ['name', 'version', 'main', 'scripts', 'dependencies'];
  requiredFields.forEach(field => {
    if (pkg[field]) {
      console.log(`  ✅ ${field} field present`);
    } else {
      console.log(`  ⚠️  ${field} field missing`);
    }
  });
  
  // Check for @octokit/rest dependency
  if (pkg.dependencies && pkg.dependencies['@octokit/rest']) {
    console.log('  ✅ @octokit/rest dependency specified');
  } else {
    console.log('  ❌ @octokit/rest dependency missing');
    allFilesExist = false;
  }
} catch (error) {
  console.log(`  ❌ package.json error: ${error.message}`);
  allFilesExist = false;
}

// Test 5: Validate issue templates
console.log('\n📝 Validating issue templates:');
const templateDir = path.join(__dirname, '.github', 'ISSUE_TEMPLATE');
const templates = ['bug_report.md', 'feature_request.md', 'translation_request.md'];

templates.forEach(template => {
  const templatePath = path.join(templateDir, template);
  try {
    const content = fs.readFileSync(templatePath, 'utf8');
    
    // Check for YAML frontmatter
    if (content.startsWith('---')) {
      console.log(`  ✅ ${template} has valid frontmatter`);
      
      // Check for required sections
      if (content.includes('name:') && content.includes('description:')) {
        console.log(`  ✅ ${template} has required metadata`);
      } else {
        console.log(`  ⚠️  ${template} missing some metadata`);
      }
    } else {
      console.log(`  ❌ ${template} missing YAML frontmatter`);
      allFilesExist = false;
    }
  } catch (error) {
    console.log(`  ❌ ${template} error: ${error.message}`);
    allFilesExist = false;
  }
});

// Test 6: Validate main automation script
console.log('\n🤖 Validating main automation script:');
try {
  const scriptPath = path.join(__dirname, 'issue-automation.js');
  const scriptContent = fs.readFileSync(scriptPath, 'utf8');
  
  // Check for required imports and class
  const checks = [
    { name: 'Octokit import', regex: /require\('@octokit\/rest'\)/ },
    { name: 'IssueAutomation class', regex: /class IssueAutomation/ },
    { name: 'CLI interface', regex: /async function main/ },
    { name: 'Triage method', regex: /async triageIssues/ }
  ];
  
  checks.forEach(check => {
    if (check.regex.test(scriptContent)) {
      console.log(`  ✅ ${check.name} present`);
    } else {
      console.log(`  ⚠️  ${check.name} not found`);
    }
  });
} catch (error) {
  console.log(`  ❌ Script error: ${error.message}`);
  allFilesExist = false;
}

// Summary
console.log('\n' + '='.repeat(50));
if (allFilesExist) {
  console.log('🎉 All tests passed! The automation setup is ready.');
  console.log('\nNext steps:');
  console.log('1. Commit and push these files to GitHub');
  console.log('2. GitHub Actions will automatically run the workflow');
  console.log('3. New issues will be automatically triaged');
  console.log('4. Use `npm install` to set up local development');
} else {
  console.log('⚠️  Some tests failed. Please check the errors above.');
  console.log('\nCommon issues:');
  console.log('- Missing files or directories');
  console.log('- Invalid JSON or YAML syntax');
  console.log('- Incorrect file paths');
}
console.log('='.repeat(50) + '\n');

// Provide setup instructions
console.log('📋 Quick Setup Guide:');
console.log(`
1. Commit and push to GitHub:
   git add .
   git commit -m "Add GitHub issue automation"
   git push

2. Enable GitHub Actions (if not already enabled):
   - Go to repository Settings → Actions → General
   - Ensure "Allow all actions" is selected

3. Test the workflow:
   - Create a test issue in the repository
   - Check the Actions tab to see the workflow run
   - Verify labels and welcome message are added

4. Local development (optional):
   npm install
   export GITHUB_TOKEN=your_token_here
   npm run triage -- --token $GITHUB_TOKEN
`);