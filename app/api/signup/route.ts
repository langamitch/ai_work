import { NextRequest, NextResponse } from "next/server";
import { createRouteHandlerClient } from "@/lib/supabase-server";

export async function POST(request: NextRequest) {
  const { email, password, displayName } = await request.json();

  if (!email || !password) {
    return NextResponse.json(
      { error: "Email and password are required" },
      { status: 400 },
    );
  }

  const supabase = await createRouteHandlerClient();

  const { data, error } = await supabase.auth.signUp({
    email,
    password,
    options: {
      data: {
        display_name: displayName,
      },
    },
  });

  if (error) {
    return NextResponse.json({ error: error.message }, { status: 400 });
  }

  // If user is created, upsert to users table
  if (data.user) {
    const { error: upsertError } = await supabase.from("users").upsert(
      {
        id: data.user.id,
        email: data.user.email,
        display_name: displayName,
        created_at: new Date().toISOString(),
        updated_at: new Date().toISOString(),
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
