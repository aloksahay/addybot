const express = require('express');
const cors = require('cors');
const { Octokit } = require('octokit');
const OpenAI = require('openai');
const { ethers } = require('ethers');
const axios = require('axios');
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

// Standard ERC721 ABI for balanceOf and tokenOfOwnerByIndex
const ERC721_ABI = [
  "function balanceOf(address owner) view returns (uint256)",
  "function tokenOfOwnerByIndex(address owner, uint256 index) view returns (uint256)",
  "function tokenURI(uint256 tokenId) view returns (string)"
];

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
    const notionResponse = await fetch(`https://api.notion.com/v1/databases/${process.env.NOTION_DATABASE_ID}/query`, {
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

    if (!notionResponse.ok) {
      throw new Error(`Notion API responded with status: ${notionResponse.status}`);
    }

    const data = await notionResponse.json();
    
    // Clean and transform the data
    const tasks = data.results.map(item => ({
      task: item.properties.Task.title[0]?.plain_text || '',
      status: item.properties.Status.status?.name || '',
      deadline: item.properties.Deadline.date?.start || null,
      hoursEstimate: item.properties['Hours estimate'].number || 0,
      category: item.properties.Category.select?.name || '',
      completion: item.properties.Completion.number || 0
    }));

    // Calculate overall completion
    const totalTasks = tasks.length;
    const completionSum = tasks.reduce((sum, task) => sum + (task.completion || 0), 0);
    const overallCompletion = totalTasks > 0 ? completionSum / totalTasks : 0;

    // Get AI recommendations
    const completion = await openai.chat.completions.create({
      model: "gpt-4-turbo-preview",
      messages: [
        {
          role: "system",
          content: `You are a productivity assistant that helps prioritize tasks and create focused work sessions. 
          Consider the following criteria:
          1. Urgency: 
             - Tasks with immediate deadlines (within 7 days) are highest priority
             - Tasks with deadlines within a month are medium priority
             - Tasks without deadlines are considered ongoing but lower priority
          2. Duration: 
             - Users work best in 30min-3hour sessions
             - Break longer tasks (>3 hours) into smaller sessions
             - Consider current completion % when suggesting session length
          3. Completion Status:
             - Prioritize in-progress tasks that are close to completion
             - For tasks with low completion %, suggest shorter initial sessions
          
          Analyze the tasks and recommend the TOP 5 tasks to focus on, with concrete timeboxed session plans.
          For tasks with deadlines, calculate and show the exact days remaining.`
        },
        {
          role: "user",
          content: `Here are my current tasks: ${JSON.stringify(tasks, null, 2)}. 
          What are the top 5 tasks I should work on and in what order? Please format the response as JSON with fields:
          - recommendations: array of 5 objects containing:
            - taskName: the recommended task
            - sessionDuration: recommended minutes for this session
            - priority: number from 1-5 (1 being highest priority)
            - reason: brief explanation of why this task was chosen
            - currentCompletion: current completion percentage of this task
            - targetCompletion: what completion percentage to aim for in this session
            - deadline: the task's deadline date (if any)
            - timeRemaining: days remaining until deadline (e.g., "4 days remaining", "Due today", or "No deadline")`
        }
      ],
      response_format: { type: "json_object" }
    });

    const recommendations = JSON.parse(completion.choices[0].message.content);
    
    // Add overall completion stats to the response
    const finalResponse = {
      overallProgress: {
        completion: overallCompletion,
        totalTasks,
        completedTasks: tasks.filter(task => task.completion === 1).length,
        inProgressTasks: tasks.filter(task => task.completion > 0 && task.completion < 1).length,
        notStartedTasks: tasks.filter(task => task.completion === 0).length,
        tasksWithDeadlines: tasks.filter(task => task.deadline !== null).length
      },
      ...recommendations
    };

    res.json(finalResponse);

  } catch (error) {
    console.error('Error getting task recommendations:', error);
    res.status(500).json({ error: error.message });
  }
});

// NFT holdings endpoint
app.get('/nft-holdings', async (req, res) => {
  try {
    const { walletAddress } = req.query;
    const contractAddress = '0x6847f4ef767fc976f9158a1d0de7cb60e1af4ebf';
    
    if (!walletAddress) {
      throw new Error('Wallet address is required');
    }

    // Connect to Mantle Sepolia
    const provider = new ethers.JsonRpcProvider('https://rpc.sepolia.mantle.xyz');
    const nftContract = new ethers.Contract(contractAddress, ERC721_ABI, provider);

    // Get number of NFTs owned by the wallet
    const balance = await nftContract.balanceOf(walletAddress);
    
    // Get all token IDs owned by the wallet and their metadata
    const tokens = [];
    for (let i = 0; i < Number(balance); i++) {
      const tokenId = await nftContract.tokenOfOwnerByIndex(walletAddress, i);
      const tokenURI = await nftContract.tokenURI(tokenId);
      
      // Fetch metadata from IPFS or HTTP
      let metadata = null;
      try {
        const ipfsUrl = tokenURI.replace('ipfs://', 'https://ipfs.io/ipfs/');
        const metadataResponse = await axios.get(ipfsUrl);
        metadata = metadataResponse.data;
      } catch (metadataError) {
        console.error(`Error fetching metadata for token ${tokenId}:`, metadataError);
      }

      tokens.push({
        tokenId: tokenId.toString(),
        tokenURI,
        metadata
      });
    }

    res.json({
      walletAddress,
      contractAddress,
      balance: balance.toString(),
      tokens,
      explorerUrl: `https://sepolia.mantlescan.xyz/address/${contractAddress}`
    });

  } catch (error) {
    console.error('Error fetching NFT holdings:', error);
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