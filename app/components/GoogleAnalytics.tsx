"use client";

import { useEffect } from "react";
import { usePathname } from "next/navigation";
import Script from "next/script";

type GoogleAnalyticsProps = {
  gaId?: string;
};

declare global {
  interface Window {
    dataLayer: unknown[];
    gtag: (...args: unknown[]) => void;
  }
}

const GoogleAnalytics = ({ gaId }: GoogleAnalyticsProps) => {
  const pathname = usePathname();

  useEffect(() => {
    if (!gaId || typeof window.gtag !== "function") {
      return;
    }

    const search = window.location.search;
    const pagePath = search ? `${pathname}${search}` : pathname;
    window.gtag("config", gaId, {
      page_path: pagePath,
    });
  }, [gaId, pathname]);

  if (!gaId) {
    return null;
  }

  return (
    <>
      <Script
        src={`https://www.googletagmanager.com/gtag/js?id=${gaId}`}
        strategy="afterInteractive"
      />
      <Script id="google-analytics" strategy="afterInteractive">
        {`
          window.dataLayer = window.dataLayer || [];
          function gtag(){dataLayer.push(arguments);}
          window.gtag = gtag;
          gtag('js', new Date());
          gtag('config', '${gaId}', { send_page_view: false });
        `}
      </Script>
    </>
  );
};

export default GoogleAnalytics;
