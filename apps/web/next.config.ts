import type { NextConfig } from "next";
import path from "path";

const isGithubActions = process.env.GITHUB_ACTIONS || false;
const isVercel = Boolean(process.env.VERCEL);
const repoName = process.env.GITHUB_REPOSITORY ? process.env.GITHUB_REPOSITORY.split('/')[1] : '';
const basePath = isGithubActions && repoName && !isVercel ? `/${repoName}` : (process.env.NEXT_PUBLIC_BASE_PATH || '');

/**
 * Deployment strategy for the Firebase-backed app:
 *
 * - GitHub Pages (CI): `output: 'export'` produces a fully static bundle.
 *   User-created board ids are dynamic, so board deep links are resolved
 *   client-side (static studio routes with `?id=` + app/not-found fallback).
 * - Vercel / Node hosts: dynamic rendering. `/dashboard/boards/[id]` is
 *   server-rendered on demand, so every board deep link resolves.
 * - Local builds: dynamic rendering so `next start` and board routes work.
 */
const isStaticExport = Boolean(isGithubActions) && !isVercel;

const nextConfig: NextConfig = {
  ...(isStaticExport ? { output: 'export' as const } : {}),
  basePath: basePath,
  trailingSlash: true,
  // Expose the computed basePath to client code (deep-link fallback in not-found).
  env: {
    NEXT_PUBLIC_BASE_PATH: basePath,
    // Tells dynamic board pages which build mode they compile for: static
    // exports must NOT prerender unbounded board ids (the 404.html SPA
    // fallback resolves them), dynamic hosts render every id on demand.
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
