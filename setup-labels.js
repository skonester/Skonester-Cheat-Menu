#!/usr/bin/env node

/**
 * GitHub Labels Setup Script
 * 
 * This script sets up standardized labels for the repository.
 * Run with: node setup-labels.js --token <GITHUB_TOKEN>
 */

const { Octokit } = require('@octokit/rest');
const fs = require('fs');
const path = require('path');

const REPO_OWNER = 'skonester';
const REPO_NAME = 'Skonester-Cheat-Menu';
const LABELS_FILE = path.join(__dirname, '.github', 'labels.json');

class LabelSetup {
  constructor(token) {
    this.octokit = new Octokit({ auth: token });
  }

  async setupLabels() {
    console.log('🏷️  Setting up GitHub labels...\n');
    
    try {
      // Read labels configuration
      const labelsData = fs.readFileSync(LABELS_FILE, 'utf8');
      const labels = JSON.parse(labelsData);
      
      // Get existing labels
      const { data: existingLabels } = await this.octokit.issues.listLabelsForRepo({
        owner: REPO_OWNER,
        repo: REPO_NAME,
        per_page: 100
      });

      const existingLabelNames = new Set(existingLabels.map(label => label.name));
      
      // Create or update labels
      for (const label of labels) {
        if (existingLabelNames.has(label.name)) {
          // Update existing label
          await this.octokit.issues.updateLabel({
            owner: REPO_OWNER,
            repo: REPO_NAME,
            name: label.name,
            new_name: label.name,
            color: label.color,
            description: label.description
          });
          console.log(`  🔄 Updated: ${label.name}`);
        } else {
          // Create new label
          await this.octokit.issues.createLabel({
            owner: REPO_OWNER,
            repo: REPO_NAME,
            name: label.name,
            color: label.color,
            description: label.description
          });
          console.log(`  ✅ Created: ${label.name}`);
        }
      }
      
      // Delete extra labels (optional)
      const configuredLabelNames = new Set(labels.map(label => label.name));
      for (const existingLabel of existingLabels) {
        if (!configuredLabelNames.has(existingLabel.name)) {
          console.log(`  ⚠️  Extra label found: ${existingLabel.name} (not in configuration)`);
          // Uncomment to delete extra labels:
          // await this.octokit.issues.deleteLabel({
          //   owner: REPO_OWNER,
          //   repo: REPO_NAME,
          //   name: existingLabel.name
          // });
          // console.log(`  🗑️  Deleted: ${existingLabel.name}`);
        }
      }
      
      console.log(`\n🎉 Label setup complete! Configured ${labels.length} labels.`);
      
    } catch (error) {
      console.error('Error setting up labels:', error.message);
      if (error.status === 404) {
        console.error('Repository not found. Check REPO_OWNER and REPO_NAME constants.');
      }
    }
  }

  async listLabels() {
    console.log('📋 Current labels in repository:\n');
    
    try {
      const { data: labels } = await this.octokit.issues.listLabelsForRepo({
        owner: REPO_OWNER,
        repo: REPO_NAME,
        per_page: 100
      });
      
      labels.forEach(label => {
        console.log(`  ████ ${label.color} ${label.name}`);
        if (label.description) {
          console.log(`      ${label.description}`);
        }
      });
      
      console.log(`\nTotal: ${labels.length} labels`);
    } catch (error) {
      console.error('Error listing labels:', error.message);
    }
  }
}

// CLI interface
async function main() {
  const args = process.argv.slice(2);
  const tokenIndex = args.indexOf('--token');
  
  if (tokenIndex === -1) {
    console.log(`
Usage: node setup-labels.js --token <GITHUB_TOKEN> [command]

Commands:
  setup    - Set up labels from configuration (default)
  list     - List current labels

Example:
  node setup-labels.js --token ghp_abc123 setup
    `);
    process.exit(1);
  }

  const token = args[tokenIndex + 1];
  const command = args[tokenIndex + 2] || 'setup';
  
  const labelSetup = new LabelSetup(token);

  switch (command) {
    case 'setup':
      await labelSetup.setupLabels();
      break;
    case 'list':
      await labelSetup.listLabels();
      break;
    default:
      console.error(`Unknown command: ${command}`);
      process.exit(1);
  }
}

if (require.main === module) {
  main().catch(console.error);
}

module.exports = LabelSetup;