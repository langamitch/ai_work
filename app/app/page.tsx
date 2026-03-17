"use client";

import React from "react";
import { useRouter } from "next/navigation";
import { createClientComponent } from '@/lib/supabase-client';

const Page = () => {
  const router = useRouter();
  const supabase = createClientComponent();

  const handleSignOut = async () => {
    await fetch("/api/signout", { method: "POST" });
    router.push("/signin");
  };

  return (
    <div className="flex flex-col items-center justify-center h-screen">
      <h1 className="text-xl mb-4">Workspace Home</h1>
      <p className="mb-4 text-gray-600">Start by creating a new project or opening an existing workspace.</p>

      <button
        onClick={() => router.push("/create")}
        className="mt-2 p-2 text-white price mix-blend-difference rounded-sm w-[200px] cursor-pointer"
      >
        Create New Project
      </button>

      <button
        onClick={() => router.push("/app/design")}
        className="mt-2 p-2 text-white price mix-blend-difference rounded-sm w-[200px] cursor-pointer"
      >
        Open Design Workspace
      </button>

      <button
        onClick={handleSignOut}
        className="mt-4 p-2 bg-red-500 text-white rounded-sm w-[200px] cursor-pointer"
      >
        Sign Out
      </button>
    </div>
  );
};

export default Page;
