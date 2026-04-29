# GitHub Issue Automation for Skonester Cheat Menu

This setup provides automated issue management for the Skonester Cheat Menu mod using GitHub's free tier features.

## Features

### 🚀 Automated Issue Triage
- **Auto-labeling**: Issues are automatically labeled based on their content (bug, enhancement, translation, etc.)
- **Welcome messages**: New issues receive a welcome message with guidelines
- **Duplicate detection**: Identifies potential duplicate issues
- **Stale issue management**: Automatically flags issues that haven't been updated in 30 days
- **🤖 AI-Powered Analysis**: Uses Gemini to analyze bug reports and suggest fixes based on the codebase

### 📋 Issue Templates
- **Bug Report Template**: Structured template for reporting bugs
- **Feature Request Template**: Template for suggesting new features
- **Translation Request Template**: For translation-related issues

### 🔧 GitHub Actions Workflow
- Runs automatically on issue events (opened, edited, commented)
- No manual intervention required
- Uses GitHub's free tier resources
- **AI Agent Integration**: Connects to Gemini for deep issue analysis

## Setup Instructions

### 1. GitHub Actions Setup
The workflow is already configured in `.github/workflows/issue-automation.yml`. It will automatically run when:
- New issues are opened
- Issues are edited
- Comments are added to issues

### 2. Local Development Setup
To run the automation scripts locally:

```bash
# Install dependencies
npm install

# Set up GitHub token (required for local execution)
export GITHUB_TOKEN=your_github_token_here

# Run issue triage
npm run triage -- --token $GITHUB_TOKEN

# Or use the direct command
node issue-automation.js --token $GITHUB_TOKEN --action triage
```

### 3. GitHub Token Setup
For local execution or custom workflows, you need a GitHub Personal Access Token:

1. Go to GitHub → Settings → Developer settings → Personal access tokens → Tokens (classic)
2. Generate a new token with `repo` scope
3. Save the token securely

### 4. AI Agent Setup (Gemini)
To enable the AI analysis:
1. Get a Gemini API Key from [Google AI Studio](https://aistudio.google.com/).
2. In your GitHub repository, go to **Settings → Secrets and variables → Actions**.
3. Create a **New repository secret** named `GEMINI_API_KEY` and paste your key.
4. The AI agent will now automatically comment on new issues!

## Usage

### Automated Workflow (Recommended)
The GitHub Actions workflow runs automatically. No manual steps required.

### Manual Execution
```bash
# Triage issues (auto-label, welcome messages, duplicate check)
npm run triage -- --token YOUR_TOKEN

# Clean up stale issues
npm run cleanup -- --token YOUR_TOKEN

# Generate issue statistics
npm run stats -- --token YOUR_TOKEN

# Run AI analysis manually
export GITHUB_TOKEN=YOUR_TOKEN
export GEMINI_API_KEY=YOUR_GEMINI_KEY
export ISSUE_NUMBER=123
npm run ai-analyze
```

### As a Global CLI Tool
```bash
# Install globally
npm install -g .

# Run from anywhere
skonester-issue-automation --token YOUR_TOKEN --action triage
```

## Configuration

Edit `.github/issue-automation.json` to customize:

```json
{
  "autoLabel": {
    "enabled": true,
    "patterns": {
      "bug": ["bug", "error", "crash"],
      "enhancement": ["feature", "enhancement"]
    }
  },
  "welcomeMessage": {
    "enabled": true
  }
}
```

## Issue Templates

The templates in `.github/ISSUE_TEMPLATE/` provide structured forms for:
- 🐛 Bug reports
- ✨ Feature requests
- 🌐 Translation requests

Users will see these templates when creating new issues on GitHub.

## Customization

### Adding New Labels
1. Update the label patterns in `issue-automation.json`
2. Add corresponding label in GitHub repository settings
3. The automation will automatically apply labels based on content

### Modifying Welcome Messages
Edit the welcome message in:
- `.github/workflows/issue-automation.yml` (line ~80-100)
- `issue-automation.js` (line ~150-170)

### Adding New Automation Rules
Extend the `IssueAutomation` class in `issue-automation.js`:

```javascript
class ExtendedAutomation extends IssueAutomation {
  async myNewFeature(issue) {
    // Your custom logic here
  }
}
```

## Troubleshooting

### GitHub Actions Not Running
1. Check that workflows are enabled in repository settings
2. Verify the workflow file is in `.github/workflows/`
3. Check Actions tab for error logs

### Local Script Errors
1. Ensure Node.js 16+ is installed
2. Verify GitHub token has correct permissions
3. Check network connectivity to GitHub API

### Labels Not Being Applied
1. Verify labels exist in GitHub repository
2. Check pattern matching in configuration
3. Review GitHub Actions logs

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test locally with `npm test`
5. Submit a pull request

## License

MIT License - see LICENSE file for details

## Support

For issues with the automation setup:
1. Check the troubleshooting section above
2. Review GitHub Actions logs
3. Open an issue in the repository