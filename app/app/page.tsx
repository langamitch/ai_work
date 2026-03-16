"use client";

import React from 'react'
import { useRouter } from 'next/navigation';

const Page = () => {
  const router = useRouter();

  return (
    <div className="flex flex-col items-center justify-center h-screen">

      <h1 className="text-xl mb-4">Home</h1>

      <button
        onClick={() => router.push("/app/design")}
        className="mt-2 p-2 text-white price mix-blend-difference rounded-sm w-[200px] cursor-pointer"
      >
        Create file
      </button>

    </div>
  )
}

export default Page