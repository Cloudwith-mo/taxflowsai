// build.js
const esbuild = require('esbuild');

const API_BASE = 'https://dql2om6jc.execute-api.us-east-1.amazonaws.com/default';

esbuild.build({
  entryPoints: ['src/login.js'],        // replace with your actual entry point file
  bundle: true,
  minify: true,
  define: { API_BASE: `"${API_BASE}"` },
  outfile: 'build/pageScript_bundle.js'
}).catch((err) => {
  console.error(err);
  process.exit(1);
});
