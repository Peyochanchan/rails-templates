import esbuild from 'esbuild';
import chokidar from 'chokidar';
import * as http from 'http';
import * as path from 'path';

// Setup for hot-reloading server
const clients = [];
http.createServer((req, res) => {
  clients.push(res);
  res.writeHead(200, {
    "Content-Type": "text/event-stream",
    "Cache-Control": "no-cache",
    "Access-Control-Allow-Origin": "http://localhost:3000",
    Connection: "keep-alive",
  });
}).listen(8082);

// esbuild configuration
const esbuildConfig = {
  entryPoints: [path.join(process.cwd(), "app/javascript", "application.js")],
  bundle: true,
  outdir: path.join(process.cwd(), "app/assets/builds"),
  banner: {
    js: '(() => new EventSource("http://localhost:8082").onmessage = () => location.reload())();',
  },
};

// Function to perform build with esbuild
function build() {
  return esbuild.build(esbuildConfig).catch(() => process.exit(1));
}

// Initial build
build();

if (process.argv.includes('--watch')) {
  // File watcher setup with chokidar
  chokidar.watch([
    "app/javascript/**/*.js",
    "app/views/**/*.html.erb",
    "app/assets/builds/application.css",
    "app/assets/builds/tailwind.css",
    "app/assets/stylesheets/application.tailwind.css"
  ]).on('all', (event, path) => {
    console.log(`Detected change in ${path}, rebuilding...`);
    build().then(() => {
      clients.forEach((res) => res.write('data: update\n\n')); // Notify clients to reload
      clients.length = 0;
    });
  });
}
