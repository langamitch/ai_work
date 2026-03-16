'use client';
import React from 'react'
import Navbar from './../components/Navbar';
import InputArea from './../components/InputArea';
import { useRouter } from 'next/navigation';

const Page = () => {

   const router = useRouter();

  return (
    <div className='mono w-full min-h-screen'>
      <Navbar />

      <div className='flex h-screen'>

        {/* Left Image */}
        <div className='w-1/2 h-full'>
          <img 
            src="/signinpage.avif" 
            alt="signin" 
            className='w-full h-full object-cover'
          />
        </div>

        {/* Right Text */}
        <div className='w-1/2 flex flex-col justify-center items-center px-10'>
          <h1 className='text-2xl md:text-xl mb-2 uppercase'>
            Welcome to WARPSTUDIO
          </h1>
          <p className='text-gray-500 text-center mb-6'>
            Sign up to continue building amazing <br /> AI workflows.
          </p>
          
          {/* Form */}
          <div className='w-[360px] flex flex-col gap-2'>
            <InputArea 
              label="Email"
              type="email"
              placeholder="Enter your email"
            />

            <InputArea 
              label="Password"
              type="password"
              placeholder="Enter your password"
            />

            {/* Sign In Button */}
            <button className='mt-2 p-2 text-white price mix-blend-difference rounded-sm w-full cursor-pointer'>
              Sign Up
            </button>
            
            {/* Divider */}
            <p className='text-center text-gray-400 mt-2 mb-2'>Or Sign Up With</p>

            {/* Social Buttons */}
            <div className='flex  gap-3'>
              <button className='p-2 bg-black text-white w-full flex items-center justify-center border rounded-sm transition'>
                <img 
                  src="/google-icon.svg" 
                  alt="Google" 
                  className='w-5 h-5 mr-2'
                />
                Google
              </button>
              
              <button className='p-2 bg-black text-white w-full flex items-center justify-center border rounded-sm transition'>
                <img 
                  src="/microsoft-icon.svg" 
                  alt="Microsoft" 
                  className='w-5 h-5 mr-2'
                />
                Microsoft
              </button>
            </div>
          <div className='my-2 text-center flex gap-2'>
            <span>Already have an account?</span>
            <span
            onClick={() => router.push("/signin")}
              className='px-2 cursor-pointer'>Sign in.</span>
          </div>
          </div>
        </div>

      </div>
    </div>
  )
}

export default Page