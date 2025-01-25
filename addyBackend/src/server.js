const express = require('express');
const cors = require('cors');
const { Octokit } = require('octokit');
require('dotenv').config();

const app = express();
const port = process.env.PORT || 3000;

// Initialize Octokit
const octokit = new Octokit({
  auth: process.env.GITHUB_TOKEN
});

// Middleware
app.use(cors());
app.use(express.json());

// Basic health check endpoint
app.get('/health', (req, res) => {
  res.json({ status: 'ok' });
});

// Notion database endpoint
app.get('/notion-data', async (req, res) => {
  try {
    const response = await fetch(`https://api.notion.com/v1/databases/${process.env.NOTION_DATABASE_ID}/query`, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${process.env.NOTION_KEY}`,
        'Notion-Version': '2022-06-28',
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        page_size: 100
      })
    });

    if (!response.ok) {
      throw new Error(`Notion API responded with status: ${response.status}`);
    }

    const data = await response.json();
    
    // Clean and transform the data
    const cleanedData = data.results.map(item => ({
      task: item.properties.Task.title[0]?.plain_text || '',
      status: item.properties.Status.status?.name || '',
      deadline: item.properties.Deadline.date?.start || null,
      hoursEstimate: item.properties['Hours estimate'].number || 0,
      category: item.properties.Category.select?.name || ''
    }));

    res.json(cleanedData);
  } catch (error) {
    console.error('Error fetching from Notion:', error);
    res.status(500).json({ error: error.message });
  }
});

// GitHub latest commit endpoint
app.get('/github-latest', async (req, res) => {
  try {
    // Get latest commits directly from the repo
    const { data: repos } = await octokit.request('GET /users/{username}/repos', {
      username: process.env.GITHUB_USERNAME,
      sort: 'pushed',
      direction: 'desc',
      per_page: 1
    });

    if (!repos.length) {
      throw new Error('No repositories found');
    }

    const repo = repos[0];
    const { data: commits } = await octokit.request('GET /repos/{owner}/{repo}/commits', {
      owner: repo.owner.login,
      repo: repo.name,
      per_page: 1
    });

    if (!commits.length) {
      throw new Error('No commits found in repository');
    }

    // Get detailed commit info with stats
    const { data: detailedCommit } = await octokit.request('GET /repos/{owner}/{repo}/commits/{commit_sha}', {
      owner: repo.owner.login,
      repo: repo.name,
      commit_sha: commits[0].sha
    });

    const commitInfo = {
      repo: `${repo.owner.login}/${repo.name}`,
      message: detailedCommit.commit.message,
      date: detailedCommit.commit.committer.date,
      stats: {
        additions: detailedCommit.stats.additions,
        deletions: detailedCommit.stats.deletions,
        total: detailedCommit.stats.total
      },
      url: detailedCommit.html_url,
      author: detailedCommit.commit.author.name
    };

    res.json(commitInfo);
  } catch (error) {
    console.error('Error fetching from GitHub:', error);
    res.status(500).json({ error: error.message });
  }
});

// GitHub recent commits endpoint
app.get('/github-commits', async (req, res) => {
  try {
    // Get most recently pushed repo
    const { data: repos } = await octokit.request('GET /users/{username}/repos', {
      username: process.env.GITHUB_USERNAME,
      sort: 'pushed',
      direction: 'desc',
      per_page: 1
    });

    if (!repos.length) {
      throw new Error('No repositories found');
    }

    const repo = repos[0];
    
    // Get latest commit from this repo
    const { data: commits } = await octokit.request('GET /repos/{owner}/{repo}/commits', {
      owner: repo.owner.login,
      repo: repo.name,
      per_page: 1
    });

    if (!commits.length) {
      throw new Error('No commits found in repository');
    }

    // Get detailed commit info
    const { data: detailedCommit } = await octokit.request('GET /repos/{owner}/{repo}/commits/{commit_sha}', {
      owner: repo.owner.login,
      repo: repo.name,
      commit_sha: commits[0].sha
    });

    // Return only the latest commit with minimal info
    res.json({
      repo: `${repo.owner.login}/${repo.name}`,
      message: detailedCommit.commit.message,
      stats: {
        additions: detailedCommit.stats.additions,
        deletions: detailedCommit.stats.deletions
      }
    });
  } catch (error) {
    console.error('Error fetching from GitHub:', error);
    res.status(500).json({ error: error.message });
  }
});

// Error handling middleware
app.use((err, req, res, next) => {
  console.error(err.stack);
  res.status(500).json({ error: 'Something went wrong!' });
});

app.listen(port, () => {
  console.log(`Server is running on port ${port}`);
}); 