import { NextRequest, NextResponse } from "next/server";
import { createRouteHandlerClient } from "@/lib/supabase-server";

export async function POST(request: NextRequest) {
  const { email, password } = await request.json();

  if (!email || !password) {
    return NextResponse.json(
      { error: "Email and password are required" },
      { status: 400 },
    );
  }

  const supabase = await createRouteHandlerClient();

  const { data, error } = await supabase.auth.signInWithPassword({
    email,
    password,
  });

  if (error) {
    return NextResponse.json({ error: error.message }, { status: 400 });
  }

  // Upsert user data
  if (data.user) {
    const { error: upsertError } = await supabase.from("users").upsert(
      {
        id: data.user.id,
        email: data.user.email,
        email_verified: data.user.email_confirmed_at ? true : false,
        display_name: data.user.user_metadata?.full_name,
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

  return NextResponse.json({ user: data.user, session: data.session });
}
