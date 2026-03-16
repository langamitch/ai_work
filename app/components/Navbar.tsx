"use client";

import { useCallback } from "react";
import { useRouter } from "next/navigation";

const Navbar = () => {
  const router = useRouter();

  const navigateTo = useCallback(
    (path: string) => {
      router.push(path);
    },
    [router],
  );

  return (
    <div className="mono flex flex-row top-0 justify-between mix-blend-difference text-white items-center pl-3 w-full fixed text-sm">
      <div>
        <span className="cursor-pointer" onClick={() => navigateTo("/")}>
          WARPSTUDIO
        </span>
      </div>

      <div className="hidden md:flex md:gap-4">
        <span className="cursor-pointer" onClick={() => navigateTo("/pricing")}>
          PRICING
        </span>

        <span
          className="cursor-pointer"
          onClick={() => navigateTo("/collective")}
        >
          COLLECTIVE
        </span>
      </div>

      <div className="flex gap-4 justify-center items-center">
        <span
          className="cursor-pointer md:hidden"
          onClick={() => navigateTo("/pricing")}
        >
          PRICING
        </span>

        <button
          className="cursor-pointer"
          onClick={() => navigateTo("/signin")}
        >
          SIGN IN
        </button>

        <span
          className="price p-3 rounded-bl-lg cursor-pointer"
          onClick={() => navigateTo("/signup")}
        >
          START NOW
        </span>
      </div>
    </div>
  );
};

export default Navbar;
