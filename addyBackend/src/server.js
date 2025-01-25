const express = require('express');
const cors = require('cors');
const { Octokit } = require('octokit');
const OpenAI = require('openai');
require('dotenv').config();

const app = express();
const port = process.env.PORT || 3000;

// Initialize Octokit
const octokit = new Octokit({
  auth: process.env.GITHUB_TOKEN
});

// Initialize OpenAI
const openai = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY
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
      category: item.properties.Category.select?.name || '',
      completion: item.properties.Completion.number || 0
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
    
    // Get all branches
    const { data: branches } = await octokit.request('GET /repos/{owner}/{repo}/branches', {
      owner: repo.owner.login,
      repo: repo.name
    });

    // Get latest commit from each branch
    const branchCommits = await Promise.all(
      branches.map(async (branch) => {
        const { data: commits } = await octokit.request('GET /repos/{owner}/{repo}/commits', {
          owner: repo.owner.login,
          repo: repo.name,
          sha: branch.name,
          per_page: 1
        });
        return {
          branch: branch.name,
          commit: commits[0]
        };
      })
    );

    // Find the most recent commit
    const latestCommit = branchCommits.reduce((latest, current) => {
      const currentDate = new Date(current.commit.commit.committer.date);
      const latestDate = new Date(latest.commit.commit.committer.date);
      return currentDate > latestDate ? current : latest;
    });

    // Get detailed commit info
    const { data: detailedCommit } = await octokit.request('GET /repos/{owner}/{repo}/commits/{commit_sha}', {
      owner: repo.owner.login,
      repo: repo.name,
      commit_sha: latestCommit.commit.sha
    });

    // Return only the latest commit with minimal info
    res.json({
      repo: `${repo.owner.login}/${repo.name}`,
      message: detailedCommit.commit.message,
      branch: latestCommit.branch,
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

// Productivity assistant endpoint
app.get('/recommend-session', async (req, res) => {
  try {
    // First get all tasks from Notion
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
    const tasks = data.results.map(item => ({
      task: item.properties.Task.title[0]?.plain_text || '',
      status: item.properties.Status.status?.name || '',
      deadline: item.properties.Deadline.date?.start || null,
      hoursEstimate: item.properties['Hours estimate'].number || 0,
      category: item.properties.Category.select?.name || '',
      completion: item.properties.Completion.number || 0
    }));

    // Get AI recommendation
    const completion = await openai.chat.completions.create({
      model: "gpt-4-turbo-preview",
      messages: [
        {
          role: "system",
          content: `You are a productivity assistant that helps prioritize tasks and create focused work sessions. 
          Consider the following criteria:
          1. Urgency: Tasks with approaching deadlines are higher priority. Tasks without deadlines are considered ongoing but lower priority.
          2. Duration: Users work best in 30min-3hour sessions. Break longer tasks into smaller sessions.
          3. Completion: Consider current completion percentage when suggesting next steps.
          
          Analyze the tasks and recommend ONE specific task to focus on next, with a concrete timeboxed session plan.`
        },
        {
          role: "user",
          content: `Here are my current tasks: ${JSON.stringify(tasks, null, 2)}. 
          What should I work on next and for how long? Please format the response as JSON with fields:
          - taskName: the recommended task
          - sessionDuration: recommended minutes for this session
          - reason: brief explanation of why this task was chosen
          - targetCompletion: what completion percentage to aim for in this session`
        }
      ],
      response_format: { type: "json_object" }
    });

    const recommendation = JSON.parse(completion.choices[0].message.content);
    res.json(recommendation);

  } catch (error) {
    console.error('Error getting task recommendation:', error);
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