import type { Metadata } from "next";
import localFont from "next/font/local";
import { Geist_Mono } from "next/font/google";
import SmoothScroll from "./components/SmoothScroll";
import GoogleAnalytics from "./components/GoogleAnalytics";
import "./globals.css";

const helveticaNeue = localFont({
  src: "../public/fonts/HelveticaNeueMedium.woff2",
  variable: "--font-helvetica-neue",
  weight: "500",
  style: "normal",
  display: "swap",
});

const ppEditorialNewItalic = localFont({
  src: "../public/fonts/66f7fc2a92d54c5a94804e33_PPEditorialNew-Italic.woff2",
  variable: "--font-pp-editorial-new-italic",
  weight: "400",
  style: "italic",
  display: "swap",
});

const ftTogetherBold = localFont({
  src: "../public/fonts/FTTogetherUnlicensedTrial-Bold.woff2",
  variable: "--font-ft-together-bold",
  weight: "700",
  style: "normal",
  display: "swap",
});

const geistMono = Geist_Mono({
  variable: "--font-geist-mono",
  subsets: ["latin"],
});

export const metadata: Metadata = {
  title: "WIDY AI WORKSPACE",
  description: "CREATIVE AI SPACE",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en">
      <body
        className={`${helveticaNeue.variable} ${ppEditorialNewItalic.variable} ${ftTogetherBold.variable} ${geistMono.variable} antialiased`}
      >
          <SmoothScroll />
          {children}
         
          <GoogleAnalytics gaId={process.env.NEXT_PUBLIC_GA_MEASUREMENT_ID} />
  
      </body>
    </html>
  );
}
