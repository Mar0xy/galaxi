import * as http from 'http';
import * as url from 'url';
import * as simple from './api/simple';

const PORT = 3000;

interface ApiRequest {
  method: string;
  params?: any[];
}

interface ApiResponse {
  success: boolean;
  result?: any;
  error?: string;
}

// Create HTTP server for Flutter communication
const server = http.createServer(async (req, res) => {
  // Enable CORS
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  
  if (req.method === 'OPTIONS') {
    res.writeHead(200);
    res.end();
    return;
  }

  if (req.method === 'POST') {
    let body = '';
    req.on('data', chunk => {
      body += chunk.toString();
    });

    req.on('end', async () => {
      try {
        const request: ApiRequest = JSON.parse(body);
        const result = await handleApiCall(request);
        
        const response: ApiResponse = {
          success: true,
          result,
        };
        
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify(response));
      } catch (error: any) {
        const response: ApiResponse = {
          success: false,
          error: error.message,
        };
        
        res.writeHead(500, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify(response));
      }
    });
  } else {
    res.writeHead(404);
    res.end('Not found');
  }
});

async function handleApiCall(request: ApiRequest): Promise<any> {
  const { method, params = [] } = request;

  // Map method names to functions
  const api: any = simple;

  if (typeof api[method] === 'function') {
    return await api[method](...params);
  } else {
    throw new Error(`Unknown method: ${method}`);
  }
}

server.listen(PORT, () => {
  console.log(`Galaxi backend server running on port ${PORT}`);
});

// Handle graceful shutdown
process.on('SIGINT', () => {
  console.log('\nShutting down backend server...');
  server.close(() => {
    console.log('Server closed');
    process.exit(0);
  });
});

process.on('SIGTERM', () => {
  console.log('\nShutting down backend server...');
  server.close(() => {
    console.log('Server closed');
    process.exit(0);
  });
});
