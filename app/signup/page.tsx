"use client";
import React, { useState } from "react";
import Navbar from "./../components/Navbar";
import InputArea from "./../components/InputArea";
import { useRouter } from "next/navigation";
import { createClientComponent } from '@/lib/supabase-client';

const Page = () => {
  const router = useRouter();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [confirmPassword, setConfirmPassword] = useState("");
  const [displayName, setDisplayName] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");

  const supabase = createClientComponent();

  const handleSignUp = async (e: React.FormEvent) => {
    e.preventDefault();
    if (password !== confirmPassword) {
      setError("Passwords do not match");
      return;
    }
    setLoading(true);
    setError("");

    const response = await fetch("/api/signup", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ email, password, displayName }),
    });
    const data = await response.json();

    if (data.error) {
      setError(data.error);
    } else {
      router.push("/create");
    }
    setLoading(false);
  };

  const handleGoogleSignUp = async () => {
    setLoading(true);
    const { error } = await supabase.auth.signInWithOAuth({
      provider: "google",
      options: {
        redirectTo: `${window.location.origin}/api/auth/callback/google`,
      },
    });
    if (error) {
      setError(error.message);
      setLoading(false);
    }
  };

  return (
    <div className="mono w-full min-h-screen">
      <Navbar />

      <div className="flex h-screen">
        {/* Left Image */}
        <div className="w-1/2 h-full">
          <img
            src="/signinpage.avif"
            alt="signin"
            className="w-full h-full object-cover"
          />
        </div>

        {/* Right Text */}
        <div className="w-1/2 flex flex-col justify-center items-center px-10">
          <h1 className="text-2xl md:text-xl mb-2 uppercase">
            Welcome to WARPSTUDIO
          </h1>
          <p className="text-gray-500 text-center mb-6">
            Sign up to continue building amazing <br /> AI workflows.
          </p>

          {/* Form */}
          <form
            onSubmit={handleSignUp}
            className="w-[360px] flex flex-col gap-2"
          >
            <InputArea
              label="Display Name"
              type="text"
              placeholder="Enter your display name"
              value={displayName}
              onChange={(e) => setDisplayName(e.target.value)}
            />

            <InputArea
              label="Email"
              type="email"
              placeholder="Enter your email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
            />

            <InputArea
              label="Password"
              type="password"
              placeholder="Enter your password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
            />

            <InputArea
              label="Confirm Password"
              type="password"
              placeholder="Confirm your password"
              value={confirmPassword}
              onChange={(e) => setConfirmPassword(e.target.value)}
            />

            {error && <p className="text-red-500 text-sm">{error}</p>}

            {/* Sign Up Button */}
            <button
              type="submit"
              disabled={loading}
              className="mt-2 p-2 text-white price mix-blend-difference rounded-sm w-full cursor-pointer disabled:opacity-50"
            >
              {loading ? "Signing Up..." : "Sign Up"}
            </button>

            {/* Divider */}
            <p className="text-center text-gray-400 mt-2 mb-2">
              Or Sign Up With
            </p>

            {/* Social Buttons */}
            <div className="flex gap-3">
              <button
                type="button"
                onClick={handleGoogleSignUp}
                disabled={loading}
                className="p-2 bg-black text-white w-full flex items-center justify-center border rounded-sm transition disabled:opacity-50"
              >
                <img
                  src="/google-icon.svg"
                  alt="Google"
                  className="w-5 h-5 mr-2"
                />
                Google
              </button>

              <button className="p-2 bg-black text-white w-full flex items-center justify-center border rounded-sm transition">
                <img
                  src="/microsoft-icon.svg"
                  alt="Microsoft"
                  className="w-5 h-5 mr-2"
                />
                Microsoft
              </button>
            </div>
          </form>
          <div className="my-2 text-center flex gap-2">
            <span>Already have an account?</span>
            <span
              onClick={() => router.push("/signin")}
              className="px-2 cursor-pointer"
            >
              Sign in.
            </span>
          </div>
        </div>
      </div>
    </div>
  );
};

export default Page;
