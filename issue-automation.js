#!/usr/bin/env node

/**
 * GitHub Issue Automation Script
 * 
 * This script provides automated issue management for the Skonester Cheat Menu mod.
 * It can be run locally or as part of CI/CD pipelines.
 * 
 * Usage:
 *   node issue-automation.js --token <GITHUB_TOKEN> --action <action>
 * 
 * Actions:
 *   - triage: Auto-label and categorize new issues
 *   - cleanup: Close stale or empty issues
 *   - stats: Generate issue statistics
 */

const { Octokit } = require('@octokit/rest');
const fs = require('fs');
const path = require('path');

// Configuration
const CONFIG_PATH = path.join(__dirname, '.github', 'issue-automation.json');
const REPO_OWNER = 'skonester';
const REPO_NAME = 'Skonester-Cheat-Menu';

class IssueAutomation {
  constructor(token) {
    this.octokit = new Octokit({ auth: token });
    this.config = this.loadConfig();
  }

  loadConfig() {
    try {
      const configData = fs.readFileSync(CONFIG_PATH, 'utf8');
      return JSON.parse(configData);
    } catch (error) {
      console.warn('Could not load config file, using defaults');
      return {
        autoLabel: { enabled: true },
        welcomeMessage: { enabled: true },
        duplicateCheck: { enabled: true }
      };
    }
  }

  async triageIssues() {
    console.log('🔍 Triaging issues...');
    
    try {
      // Get open issues
      const { data: issues } = await this.octokit.issues.listForRepo({
        owner: REPO_OWNER,
        repo: REPO_NAME,
        state: 'open',
        sort: 'created',
        direction: 'desc'
      });

      for (const issue of issues) {
        console.log(`Processing issue #${issue.number}: ${issue.title}`);
        
        // Skip pull requests
        if (issue.pull_request) continue;

        // Auto-label based on content
        if (this.config.autoLabel?.enabled) {
          await this.autoLabelIssue(issue);
        }

        // Check for duplicates
        if (this.config.duplicateCheck?.enabled) {
          await this.checkForDuplicates(issue, issues);
        }

        // Add welcome message for new issues
        if (this.config.welcomeMessage?.enabled && 
            issue.comments === 0 && 
            Date.now() - new Date(issue.created_at).getTime() < 3600000) {
          await this.addWelcomeMessage(issue);
        }
      }

      console.log(`✅ Triaged ${issues.length} issues`);
    } catch (error) {
      console.error('Error triaging issues:', error.message);
    }
  }

  async autoLabelIssue(issue) {
    const title = issue.title.toLowerCase();
    const body = issue.body?.toLowerCase() || '';
    const existingLabels = issue.labels.map(label => label.name);
    
    const labelsToAdd = [];
    const patterns = this.config.autoLabel?.patterns || {};

    for (const [label, labelPatterns] of Object.entries(patterns)) {
      if (labelPatterns.some(pattern => 
          title.includes(pattern) || body.includes(pattern))) {
        if (!existingLabels.includes(label)) {
          labelsToAdd.push(label);
        }
      }
    }

    if (labelsToAdd.length > 0) {
      try {
        await this.octokit.issues.addLabels({
          owner: REPO_OWNER,
          repo: REPO_NAME,
          issue_number: issue.number,
          labels: labelsToAdd
        });
        console.log(`  Added labels: ${labelsToAdd.join(', ')}`);
      } catch (error) {
        console.error(`  Error adding labels: ${error.message}`);
      }
    }
  }

  async checkForDuplicates(issue, allIssues) {
    // Simple duplicate check based on title similarity
    const currentTitle = issue.title.toLowerCase();
    
    for (const otherIssue of allIssues) {
      if (otherIssue.number === issue.number || otherIssue.pull_request) continue;
      
      const otherTitle = otherIssue.title.toLowerCase();
      const similarity = this.calculateSimilarity(currentTitle, otherTitle);
      
      if (similarity > 0.7) { // 70% similarity threshold
        console.log(`  ⚠️  Possible duplicate of #${otherIssue.number} (similarity: ${similarity.toFixed(2)})`);
        
        // Add comment about possible duplicate
        await this.octokit.issues.createComment({
          owner: REPO_OWNER,
          repo: REPO_NAME,
          issue_number: issue.number,
          body: `⚠️ **Possible duplicate detected!**\n\nThis issue appears similar to #${otherIssue.number}: "${otherIssue.title}"\n\nPlease check if your issue is already reported and consider adding your information to the existing issue instead.`
        });
        
        // Add duplicate label
        await this.octokit.issues.addLabels({
          owner: REPO_OWNER,
          repo: REPO_NAME,
          issue_number: issue.number,
          labels: ['possible-duplicate']
        });
        
        break;
      }
    }
  }

  calculateSimilarity(str1, str2) {
    // Simple Jaccard similarity for demonstration
    const set1 = new Set(str1.split(/\s+/));
    const set2 = new Set(str2.split(/\s+/));
    
    const intersection = new Set([...set1].filter(x => set2.has(x)));
    const union = new Set([...set1, ...set2]);
    
    return intersection.size / union.size;
  }

  async addWelcomeMessage(issue) {
    const welcomeMessage = `👋 Thanks for opening issue #${issue.number}, @${issue.user.login}!

**Before we proceed, please make sure:**
1. You're using the latest version of the mod
3. You've provided enough details for us to help you

**For bug reports, please include:**
- Game version
- Mod version
- Screenshots if applicable

A maintainer will review your issue soon!`;

    try {
      await this.octokit.issues.createComment({
        owner: REPO_OWNER,
        repo: REPO_NAME,
        issue_number: issue.number,
        body: welcomeMessage
      });
      console.log(`  Added welcome message to issue #${issue.number}`);
    } catch (error) {
      console.error(`  Error adding welcome message: ${error.message}`);
    }
  }

  async cleanupStaleIssues() {
    console.log('🧹 Cleaning up stale issues...');
    
    try {
      const { data: issues } = await this.octokit.issues.listForRepo({
        owner: REPO_OWNER,
        repo: REPO_NAME,
        state: 'open',
        sort: 'updated',
        direction: 'asc'
      });

      const thirtyDaysAgo = new Date();
      thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);

      for (const issue of issues) {
        if (issue.pull_request) continue;
        
        const lastUpdated = new Date(issue.updated_at);
        
        if (lastUpdated < thirtyDaysAgo) {
          console.log(`  Issue #${issue.number} last updated ${lastUpdated.toISOString().split('T')[0]}`);
          
          // Add stale warning
          await this.octokit.issues.createComment({
            owner: REPO_OWNER,
            repo: REPO_NAME,
            issue_number: issue.number,
            body: `⚠️ **This issue hasn't been updated in 30 days.**\n\nIf this issue is still relevant, please provide an update. Otherwise, it will be closed in 7 days.`
          });
          
          // Add stale label
          await this.octokit.issues.addLabels({
            owner: REPO_OWNER,
            repo: REPO_NAME,
            issue_number: issue.number,
            labels: ['stale']
          });
        }
      }
    } catch (error) {
      console.error('Error cleaning up stale issues:', error.message);
    }
  }

  async generateStats() {
    console.log('📊 Generating issue statistics...');
    
    try {
      const { data: issues } = await this.octokit.issues.listForRepo({
        owner: REPO_OWNER,
        repo: REPO_NAME,
        state: 'all',
        per_page: 100
      });

      const stats = {
        total: issues.length,
        open: issues.filter(i => i.state === 'open').length,
        closed: issues.filter(i => i.state === 'closed').length,
        byLabel: {},
        byMonth: {}
      };

      // Count by label
      issues.forEach(issue => {
        issue.labels.forEach(label => {
          stats.byLabel[label.name] = (stats.byLabel[label.name] || 0) + 1;
        });

        // Count by month
        const month = issue.created_at.substring(0, 7); // YYYY-MM
        stats.byMonth[month] = (stats.byMonth[month] || 0) + 1;
      });

      console.log('\n📈 Issue Statistics:');
      console.log(`Total issues: ${stats.total}`);
      console.log(`Open issues: ${stats.open}`);
      console.log(`Closed issues: ${stats.closed}`);
      console.log(`\nBy label:`);
      Object.entries(stats.byLabel)
        .sort(([,a], [,b]) => b - a)
        .forEach(([label, count]) => {
          console.log(`  ${label}: ${count}`);
        });

      return stats;
    } catch (error) {
      console.error('Error generating stats:', error.message);
    }
  }
}

// CLI interface
async function main() {
  const args = process.argv.slice(2);
  const tokenIndex = args.indexOf('--token');
  const actionIndex = args.indexOf('--action');
  
  if (tokenIndex === -1 || actionIndex === -1) {
    console.log(`
Usage: node issue-automation.js --token <GITHUB_TOKEN> --action <action>

Actions:
  triage    - Auto-label and categorize new issues
  cleanup   - Close stale or empty issues
  stats     - Generate issue statistics

Example:
  node issue-automation.js --token ghp_abc123 --action triage
    `);
    process.exit(1);
  }

  const token = args[tokenIndex + 1];
  const action = args[actionIndex + 1];
  
  const automation = new IssueAutomation(token);

  switch (action) {
    case 'triage':
      await automation.triageIssues();
      break;
    case 'cleanup':
      await automation.cleanupStaleIssues();
      break;
    case 'stats':
      await automation.generateStats();
      break;
    default:
      console.error(`Unknown action: ${action}`);
      process.exit(1);
  }
}

if (require.main === module) {
  main().catch(console.error);
}

module.exports = IssueAutomation;