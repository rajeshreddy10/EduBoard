import React from "react";
import ShareClient from "./ShareClient";

// Board ids are unbounded — strategy note in `boards/[id]/page.tsx`.
export function generateStaticParams() {
  return [{ id: 'default' }];
}

export default function ShareBoardPage() {
  return <ShareClient />;
}
