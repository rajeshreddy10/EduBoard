import type { NextConfig } from "next";
import path from "path";
import fs from "fs";

const isGithubActions = Boolean(process.env.GITHUB_ACTIONS);
const isVercel = Boolean(process.env.VERCEL);
const cnameFile = path.resolve(__dirname, "public/CNAME");
const hasCustomDomain = fs.existsSync(cnameFile) && fs.readFileSync(cnameFile, "utf-8").trim().length > 0;
const repoName = process.env.GITHUB_REPOSITORY ? process.env.GITHUB_REPOSITORY.split('/')[1] : '';
const isUserPage = repoName.toLowerCase().endsWith('.github.io');

// Base path configuration:
// 1. If explicitly defined in environment (e.g. NEXT_PUBLIC_BASE_PATH), honor it.
// 2. If running on GitHub Actions without a custom domain and not a user page (<user>.github.io), prefix with /<repoName>.
// 3. Otherwise (custom domain, user page, Vercel, or local development), use empty string root ('').
let basePath = '';
if (process.env.NEXT_PUBLIC_BASE_PATH !== undefined) {
  basePath = process.env.NEXT_PUBLIC_BASE_PATH;
} else if (isGithubActions && !isVercel && !hasCustomDomain && !isUserPage && repoName) {
  basePath = `/${repoName}`;
}

const isStaticExport = Boolean(process.env.STATIC_EXPORT === 'true' || process.env.NEXT_EXPORT === 'true' || isGithubActions) && !isVercel;

const nextConfig: NextConfig = {
  ...(isStaticExport ? { output: 'export' as const } : {}),
  basePath: basePath,
  trailingSlash: true,
  // Expose the computed basePath to client code (deep-link fallback in not-found).
  env: {
    NEXT_PUBLIC_BASE_PATH: basePath,
    NEXT_PUBLIC_STATIC_EXPORT: isStaticExport ? 'true' : 'false',
  },
  images: {
    unoptimized: true,
    remotePatterns: [
      { protocol: "https", hostname: "**" },
    ],
  },
  turbopack: {
    root: path.resolve(__dirname, "../../"),
  },
  poweredByHeader: false,
  allowedDevOrigins: [
    "10.101.120.243",
    "192.168.56.1",
    "172.20.10.4",
    "10.0.2.2",
    "localhost",
    "127.0.0.1"
  ],
};

export default nextConfig;
