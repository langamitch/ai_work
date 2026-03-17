import { NextRequest, NextResponse } from 'next/server';

export async function POST(request: NextRequest) {
  const { name, slug, description } = await request.json();

  if (!name || !slug) {
    return NextResponse.json({ error: 'Name and slug are required' }, { status: 400 });
  }

  return NextResponse.json({
    success: true,
    project: {
      id: crypto.randomUUID(),
      name,
      slug,
      description: description ?? '',
      createdAt: new Date().toISOString(),
    },
  });
}
