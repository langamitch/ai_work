import { NextRequest, NextResponse } from 'next/server';

export async function POST(request: NextRequest) {
  const { name, slug } = await request.json();

  if (!name || !slug) {
    return NextResponse.json({ error: 'Name and slug are required' }, { status: 400 });
  }

  return NextResponse.json({
    success: true,
    workspace: {
      id: crypto.randomUUID(),
      name,
      slug,
      createdAt: new Date().toISOString(),
    },
  });
}
