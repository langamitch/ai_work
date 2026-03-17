import { NextRequest, NextResponse } from "next/server";
import { createRouteHandlerClient } from "@/lib/supabase-server";

export async function GET(request: NextRequest) {
  const { searchParams, origin } = new URL(request.url);
  const code = searchParams.get("code");
  const next = searchParams.get("next") ?? "/";

  if (code) {
    const supabase = await createRouteHandlerClient();
    const { error } = await supabase.auth.exchangeCodeForSession(code);

    if (!error) {
      // Get the user
      const {
        data: { user },
      } = await supabase.auth.getUser();

      if (user) {
        // Upsert user data to our custom users table
        const { error: upsertError } = await supabase.from("users").upsert(
          {
            id: user.id,
            email: user.email,
            email_verified: user.email_confirmed_at ? true : false,
            display_name:
              user.user_metadata?.full_name || user.user_metadata?.name,
            avatar_url: user.user_metadata?.avatar_url,
            google_id: user.user_metadata?.provider_id,
            last_login_at: new Date().toISOString(),
          },
          {
            onConflict: "id",
          },
        );

        if (upsertError) {
          console.error("Error upserting user:", upsertError);
        }
      }

      const forwardedHost = request.headers.get("x-forwarded-host");
      const isLocalEnv = process.env.NODE_ENV === "development";
      if (isLocalEnv) {
        return NextResponse.redirect(`${origin}${next}`);
      } else if (forwardedHost) {
        return NextResponse.redirect(`https://${forwardedHost}${next}`);
      } else {
        return NextResponse.redirect(`${origin}${next}`);
      }
    }
  }

  // Return the user to an error page with instructions
  return NextResponse.redirect(`${origin}/auth/auth-code-error`);
}
