"use client";

import { useRouter } from "next/navigation";
import { useCallback } from "react";

const useNavigate = () => {
  const router = useRouter();

  const navigateTo = useCallback((path: string) => {
    router.push(path);
  }, [router]);

  return { navigateTo };
};

export default useNavigate;