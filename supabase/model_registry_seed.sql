-- ============================================================
--  AI WORKSPACE — MODEL REGISTRY SEED
--  File 2 of 3 — run after ai_workspace_schema.sql
--
--  Models:
--    Image  — Flux Pro 1.1 Ultra, Imagen 4, NVIDIA Sana, Nano Banana
--    Video  — Veo 3, Sora, Kling v2, Runway Gen-4, Luma Ray 2,
--             Higgsfield, Seedance
--    Edit   — Topaz Video AI
--    Text   — ChatGPT Prompt Enhancer, Gemini Prompt Enhancer
-- ============================================================


-- ============================================================
-- SYSTEM USER
-- Fixed UUID used as owner of all official templates.
-- Safe to run on a fresh database with no real users yet.
-- ============================================================

INSERT INTO users (id, email, display_name, email_verified)
VALUES ('00000000-0000-0000-0000-000000000001', 'system@workspace.internal', 'System', TRUE)
ON CONFLICT (id) DO NOTHING;


-- ============================================================
-- IMAGE GENERATION
-- ============================================================

INSERT INTO ai_models (
    provider, model_name, model_version, display_name,
    modality, sub_modality, credit_cost, cost_variable,
    is_active, is_beta, avg_latency_ms,
    supported_formats, max_batch_size,
    config_schema, default_params
) VALUES

-- ── Flux Pro 1.1 Ultra ──────────────────────────────────────
('fal', 'flux-pro-1.1-ultra', '1.1', 'Flux Pro 1.1 Ultra',
 'image', 'generation', 4, TRUE, TRUE, FALSE, 8000,
 ARRAY['png','jpeg','webp'], 4,
 '{
    "prompt":           {"type":"string",  "required":true,  "default":"",    "label":"Prompt"},
    "negative_prompt":  {"type":"string",  "required":false, "default":"",    "label":"Negative Prompt"},
    "width":            {"type":"integer", "required":false, "default":1024,  "min":512,  "max":2048, "step":64, "label":"Width"},
    "height":           {"type":"integer", "required":false, "default":1024,  "min":512,  "max":2048, "step":64, "label":"Height"},
    "steps":            {"type":"integer", "required":false, "default":50,    "min":1,    "max":100,  "label":"Steps"},
    "guidance_scale":   {"type":"number",  "required":false, "default":7.5,   "min":1,    "max":20,   "label":"Guidance Scale"},
    "seed":             {"type":"integer", "required":false, "default":null,  "label":"Seed"},
    "output_format":    {"type":"string",  "required":false, "default":"png", "enum":["png","jpeg","webp"], "label":"Output Format"},
    "safety_tolerance": {"type":"integer", "required":false, "default":2,     "min":1, "max":6, "label":"Safety Tolerance"}
 }'::jsonb,
 '{"width":1024,"height":1024,"steps":50,"guidance_scale":7.5,"output_format":"png"}'::jsonb),

-- ── Imagen 4 ────────────────────────────────────────────────
('google', 'imagen-4', '4.0', 'Imagen 4',
 'image', 'generation', 5, TRUE, TRUE, FALSE, 12000,
 ARRAY['png','jpeg'], 4,
 '{
    "prompt":           {"type":"string",  "required":true,  "default":"",          "label":"Prompt"},
    "negative_prompt":  {"type":"string",  "required":false, "default":"",          "label":"Negative Prompt"},
    "aspect_ratio":     {"type":"string",  "required":false, "default":"1:1",       "enum":["1:1","16:9","9:16","4:3","3:4"], "label":"Aspect Ratio"},
    "number_of_images": {"type":"integer", "required":false, "default":1,           "min":1, "max":4, "label":"Number of Images"},
    "seed":             {"type":"integer", "required":false, "default":null,        "label":"Seed"},
    "output_format":    {"type":"string",  "required":false, "default":"png",       "enum":["png","jpeg"], "label":"Output Format"},
    "safety_filter":    {"type":"string",  "required":false, "default":"block_some","enum":["block_few","block_some","block_most"], "label":"Safety Filter"}
 }'::jsonb,
 '{"aspect_ratio":"1:1","number_of_images":1,"output_format":"png","safety_filter":"block_some"}'::jsonb),

-- ── NVIDIA Sana 1.5 ─────────────────────────────────────────
('nvidia', 'sana-1.5', '1.5', 'NVIDIA Sana 1.5',
 'image', 'generation', 3, TRUE, TRUE, FALSE, 6000,
 ARRAY['png','jpeg'], 4,
 '{
    "prompt":          {"type":"string",  "required":true,  "default":"",             "label":"Prompt"},
    "negative_prompt": {"type":"string",  "required":false, "default":"",             "label":"Negative Prompt"},
    "width":           {"type":"integer", "required":false, "default":1024, "min":512,"max":4096,"step":64,"label":"Width"},
    "height":          {"type":"integer", "required":false, "default":1024, "min":512,"max":4096,"step":64,"label":"Height"},
    "steps":           {"type":"integer", "required":false, "default":20,  "min":1,  "max":50,  "label":"Steps"},
    "guidance_scale":  {"type":"number",  "required":false, "default":5.0, "min":1,  "max":20,  "label":"Guidance Scale"},
    "seed":            {"type":"integer", "required":false, "default":null,           "label":"Seed"},
    "style":           {"type":"string",  "required":false, "default":"photorealistic","enum":["photorealistic","digital-art","anime","illustration","cinematic"],"label":"Style"}
 }'::jsonb,
 '{"width":1024,"height":1024,"steps":20,"guidance_scale":5.0,"style":"photorealistic"}'::jsonb),

-- ── Nano Banana ─────────────────────────────────────────────
('fal', 'nano-banana', '1.0', 'Nano Banana',
 'image', 'generation', 2, TRUE, TRUE, TRUE, 4000,
 ARRAY['png','jpeg','webp'], 8,
 '{
    "prompt":          {"type":"string",  "required":true,  "default":"",    "label":"Prompt"},
    "negative_prompt": {"type":"string",  "required":false, "default":"",    "label":"Negative Prompt"},
    "width":           {"type":"integer", "required":false, "default":512,   "min":256,"max":1024,"step":64,"label":"Width"},
    "height":          {"type":"integer", "required":false, "default":512,   "min":256,"max":1024,"step":64,"label":"Height"},
    "steps":           {"type":"integer", "required":false, "default":4,     "min":1,  "max":8,  "label":"Steps"},
    "seed":            {"type":"integer", "required":false, "default":null,  "label":"Seed"},
    "output_format":   {"type":"string",  "required":false, "default":"png", "enum":["png","jpeg","webp"],"label":"Output Format"}
 }'::jsonb,
 '{"width":512,"height":512,"steps":4,"output_format":"png"}'::jsonb);


-- ============================================================
-- VIDEO GENERATION
-- ============================================================

INSERT INTO ai_models (
    provider, model_name, model_version, display_name,
    modality, sub_modality, credit_cost, cost_variable,
    is_active, is_beta, avg_latency_ms,
    supported_formats, max_batch_size,
    config_schema, default_params
) VALUES

-- ── Veo 3 ───────────────────────────────────────────────────
('google', 'veo-3', '3.0', 'Veo 3',
 'video', 'generation', 20, TRUE, TRUE, FALSE, 120000,
 ARRAY['mp4','webm'], 1,
 '{
    "prompt":          {"type":"string",  "required":true,  "default":"",     "label":"Prompt"},
    "negative_prompt": {"type":"string",  "required":false, "default":"",     "label":"Negative Prompt"},
    "duration":        {"type":"integer", "required":false, "default":5,      "enum":[5,8,10], "label":"Duration (sec)"},
    "aspect_ratio":    {"type":"string",  "required":false, "default":"16:9", "enum":["16:9","9:16","1:1"], "label":"Aspect Ratio"},
    "resolution":      {"type":"string",  "required":false, "default":"1080p","enum":["720p","1080p"], "label":"Resolution"},
    "fps":             {"type":"integer", "required":false, "default":24,     "enum":[24,30], "label":"FPS"},
    "generate_audio":  {"type":"boolean", "required":false, "default":true,   "label":"Generate Audio"},
    "seed":            {"type":"integer", "required":false, "default":null,   "label":"Seed"}
 }'::jsonb,
 '{"duration":5,"aspect_ratio":"16:9","resolution":"1080p","fps":24,"generate_audio":true}'::jsonb),

-- ── Sora ────────────────────────────────────────────────────
('openai', 'sora', '1.0', 'Sora',
 'video', 'generation', 25, TRUE, TRUE, FALSE, 180000,
 ARRAY['mp4'], 1,
 '{
    "prompt":       {"type":"string",  "required":true,  "default":"",      "label":"Prompt"},
    "duration":     {"type":"integer", "required":false, "default":5,       "enum":[5,10,20], "label":"Duration (sec)"},
    "aspect_ratio": {"type":"string",  "required":false, "default":"16:9",  "enum":["16:9","9:16","1:1"], "label":"Aspect Ratio"},
    "resolution":   {"type":"string",  "required":false, "default":"1080p", "enum":["480p","720p","1080p"], "label":"Resolution"},
    "style":        {"type":"string",  "required":false, "default":"vivid", "enum":["vivid","natural"], "label":"Style"},
    "seed":         {"type":"integer", "required":false, "default":null,    "label":"Seed"}
 }'::jsonb,
 '{"duration":5,"aspect_ratio":"16:9","resolution":"1080p","style":"vivid"}'::jsonb),

-- ── Kling v2 ────────────────────────────────────────────────
('fal', 'kling-v2', '2.0', 'Kling v2',
 'video', 'generation', 15, TRUE, TRUE, FALSE, 150000,
 ARRAY['mp4'], 1,
 '{
    "prompt":          {"type":"string",  "required":true,  "default":"",        "label":"Prompt"},
    "negative_prompt": {"type":"string",  "required":false, "default":"",        "label":"Negative Prompt"},
    "duration":        {"type":"string",  "required":false, "default":"5",       "enum":["5","10"], "label":"Duration (sec)"},
    "aspect_ratio":    {"type":"string",  "required":false, "default":"16:9",    "enum":["16:9","9:16","1:1","4:3"], "label":"Aspect Ratio"},
    "mode":            {"type":"string",  "required":false, "default":"standard","enum":["standard","pro"], "label":"Mode"},
    "image_url":       {"type":"string",  "required":false, "default":null,      "label":"Reference Image (optional)"},
    "seed":            {"type":"integer", "required":false, "default":null,      "label":"Seed"}
 }'::jsonb,
 '{"duration":"5","aspect_ratio":"16:9","mode":"standard"}'::jsonb),

-- ── Runway Gen-4 ────────────────────────────────────────────
('runway', 'gen-4', '4.0', 'Runway Gen-4',
 'video', 'generation', 18, TRUE, TRUE, FALSE, 160000,
 ARRAY['mp4'], 1,
 '{
    "prompt":        {"type":"string",  "required":true,  "default":"",      "label":"Prompt"},
    "duration":      {"type":"integer", "required":false, "default":5,       "enum":[5,10], "label":"Duration (sec)"},
    "aspect_ratio":  {"type":"string",  "required":false, "default":"16:9",  "enum":["16:9","9:16","1:1"], "label":"Aspect Ratio"},
    "resolution":    {"type":"string",  "required":false, "default":"1080p", "enum":["720p","1080p"], "label":"Resolution"},
    "camera_motion": {"type":"string",  "required":false, "default":"auto",  "enum":["auto","static","zoom_in","zoom_out","pan_left","pan_right","tilt_up","tilt_down"], "label":"Camera Motion"},
    "image_url":     {"type":"string",  "required":false, "default":null,    "label":"Reference Image (optional)"},
    "seed":          {"type":"integer", "required":false, "default":null,    "label":"Seed"}
 }'::jsonb,
 '{"duration":5,"aspect_ratio":"16:9","resolution":"1080p","camera_motion":"auto"}'::jsonb),

-- ── Luma Ray 2 ──────────────────────────────────────────────
('luma', 'ray-2', '2.0', 'Luma Ray 2',
 'video', 'generation', 16, TRUE, TRUE, FALSE, 140000,
 ARRAY['mp4'], 1,
 '{
    "prompt":         {"type":"string",  "required":true,  "default":"",     "label":"Prompt"},
    "negative_prompt":{"type":"string",  "required":false, "default":"",     "label":"Negative Prompt"},
    "duration":       {"type":"string",  "required":false, "default":"5s",   "enum":["5s","9s"], "label":"Duration"},
    "aspect_ratio":   {"type":"string",  "required":false, "default":"16:9", "enum":["16:9","9:16","1:1","4:3","21:9"], "label":"Aspect Ratio"},
    "loop":           {"type":"boolean", "required":false, "default":false,  "label":"Loop"},
    "image_url":      {"type":"string",  "required":false, "default":null,   "label":"Start Image (optional)"},
    "end_image_url":  {"type":"string",  "required":false, "default":null,   "label":"End Image (optional)"},
    "seed":           {"type":"integer", "required":false, "default":null,   "label":"Seed"}
 }'::jsonb,
 '{"duration":"5s","aspect_ratio":"16:9","loop":false}'::jsonb),

-- ── Higgsfield ──────────────────────────────────────────────
('higgsfield', 'higgsfield-1', '1.0', 'Higgsfield',
 'video', 'generation', 14, TRUE, TRUE, TRUE, 130000,
 ARRAY['mp4'], 1,
 '{
    "prompt":           {"type":"string",  "required":true,  "default":"",          "label":"Prompt"},
    "negative_prompt":  {"type":"string",  "required":false, "default":"",          "label":"Negative Prompt"},
    "duration":         {"type":"integer", "required":false, "default":4,           "min":2, "max":8, "label":"Duration (sec)"},
    "aspect_ratio":     {"type":"string",  "required":false, "default":"16:9",      "enum":["16:9","9:16","1:1"], "label":"Aspect Ratio"},
    "motion_intensity": {"type":"number",  "required":false, "default":0.5,         "min":0, "max":1, "label":"Motion Intensity"},
    "style":            {"type":"string",  "required":false, "default":"cinematic", "enum":["cinematic","realistic","stylized","anime"], "label":"Style"},
    "image_url":        {"type":"string",  "required":false, "default":null,        "label":"Reference Image (optional)"},
    "seed":             {"type":"integer", "required":false, "default":null,        "label":"Seed"}
 }'::jsonb,
 '{"duration":4,"aspect_ratio":"16:9","motion_intensity":0.5,"style":"cinematic"}'::jsonb),

-- ── Seedance ────────────────────────────────────────────────
('bytedance', 'seedance-1', '1.0', 'Seedance',
 'video', 'generation', 12, TRUE, TRUE, TRUE, 120000,
 ARRAY['mp4'], 1,
 '{
    "prompt":          {"type":"string",  "required":true,  "default":"",      "label":"Prompt"},
    "negative_prompt": {"type":"string",  "required":false, "default":"",      "label":"Negative Prompt"},
    "duration":        {"type":"integer", "required":false, "default":5,       "enum":[3,5,8,10], "label":"Duration (sec)"},
    "aspect_ratio":    {"type":"string",  "required":false, "default":"16:9",  "enum":["16:9","9:16","1:1"], "label":"Aspect Ratio"},
    "resolution":      {"type":"string",  "required":false, "default":"1080p", "enum":["720p","1080p"], "label":"Resolution"},
    "fps":             {"type":"integer", "required":false, "default":24,      "enum":[24,30], "label":"FPS"},
    "image_url":       {"type":"string",  "required":false, "default":null,    "label":"Reference Image (optional)"},
    "seed":            {"type":"integer", "required":false, "default":null,    "label":"Seed"}
 }'::jsonb,
 '{"duration":5,"aspect_ratio":"16:9","resolution":"1080p","fps":24}'::jsonb);


-- ============================================================
-- VIDEO ENHANCEMENT
-- ============================================================

INSERT INTO ai_models (
    provider, model_name, model_version, display_name,
    modality, sub_modality, credit_cost, cost_variable,
    is_active, is_beta, avg_latency_ms,
    supported_formats, max_batch_size,
    config_schema, default_params
) VALUES

-- ── Topaz Video AI ──────────────────────────────────────────
('topaz', 'topaz-video-ai', '4.0', 'Topaz Video AI',
 'video', 'enhancement', 8, TRUE, TRUE, FALSE, 300000,
 ARRAY['mp4','mov','avi'], 1,
 '{
    "video_url":         {"type":"string",  "required":true,  "default":"",         "label":"Input Video URL"},
    "enhancement_type":  {"type":"string",  "required":false, "default":"upscale",  "enum":["upscale","denoise","stabilize","interpolate","sharpen"], "label":"Enhancement Type"},
    "upscale_factor":    {"type":"string",  "required":false, "default":"2x",       "enum":["2x","4x"], "label":"Upscale Factor"},
    "output_resolution": {"type":"string",  "required":false, "default":"1080p",    "enum":["720p","1080p","4k"], "label":"Output Resolution"},
    "model":             {"type":"string",  "required":false, "default":"amion",    "enum":["amion","iris","nyx","theia","proteus","gaia"], "label":"AI Model"},
    "fps_target":        {"type":"integer", "required":false, "default":null,       "label":"Target FPS (null = keep original)"},
    "grain_reduction":   {"type":"number",  "required":false, "default":50,         "min":0, "max":100, "label":"Grain Reduction (%)"}
 }'::jsonb,
 '{"enhancement_type":"upscale","upscale_factor":"2x","output_resolution":"1080p","model":"amion","grain_reduction":50}'::jsonb);


-- ============================================================
-- PROMPT ENHANCEMENT
-- ============================================================

INSERT INTO ai_models (
    provider, model_name, model_version, display_name,
    modality, sub_modality, credit_cost, cost_variable,
    is_active, is_beta, avg_latency_ms,
    supported_formats, max_batch_size,
    config_schema, default_params
) VALUES

-- ── ChatGPT (GPT-4o) Prompt Enhancer ────────────────────────
('openai', 'gpt-4o-prompt-enhancer', '2024-11', 'ChatGPT Prompt Enhancer',
 'text', 'prompt_enhancement', 1, FALSE, TRUE, FALSE, 5000,
 ARRAY['text'], 1,
 '{
    "raw_prompt":       {"type":"string",  "required":true,  "default":"",         "label":"Raw Prompt"},
    "target_model":     {"type":"string",  "required":false, "default":"image",    "enum":["image","video","3d","audio"], "label":"Target Modality"},
    "style_reference":  {"type":"string",  "required":false, "default":"",         "label":"Style Reference (optional)"},
    "enhancement_mode": {"type":"string",  "required":false, "default":"detailed", "enum":["concise","detailed","cinematic","technical"], "label":"Enhancement Mode"},
    "add_negative":     {"type":"boolean", "required":false, "default":true,       "label":"Generate Negative Prompt"},
    "temperature":      {"type":"number",  "required":false, "default":0.7,        "min":0, "max":1, "label":"Creativity"},
    "max_tokens":       {"type":"integer", "required":false, "default":500,        "min":100, "max":2000, "label":"Max Length"}
 }'::jsonb,
 '{"target_model":"image","enhancement_mode":"detailed","add_negative":true,"temperature":0.7,"max_tokens":500}'::jsonb),

-- ── Gemini 2.0 Flash Prompt Enhancer ────────────────────────
('google', 'gemini-2.0-flash-prompt-enhancer', '2.0', 'Gemini Prompt Enhancer',
 'text', 'prompt_enhancement', 1, FALSE, TRUE, FALSE, 3000,
 ARRAY['text'], 1,
 '{
    "raw_prompt":       {"type":"string",  "required":true,  "default":"",         "label":"Raw Prompt"},
    "target_model":     {"type":"string",  "required":false, "default":"image",    "enum":["image","video","3d","audio"], "label":"Target Modality"},
    "style_reference":  {"type":"string",  "required":false, "default":"",         "label":"Style Reference (optional)"},
    "enhancement_mode": {"type":"string",  "required":false, "default":"detailed", "enum":["concise","detailed","cinematic","technical"], "label":"Enhancement Mode"},
    "add_negative":     {"type":"boolean", "required":false, "default":true,       "label":"Generate Negative Prompt"},
    "language":         {"type":"string",  "required":false, "default":"en",       "enum":["en","es","fr","de","ja","zh","pt"], "label":"Output Language"},
    "temperature":      {"type":"number",  "required":false, "default":0.7,        "min":0, "max":1, "label":"Creativity"},
    "max_tokens":       {"type":"integer", "required":false, "default":500,        "min":100, "max":2000, "label":"Max Length"}
 }'::jsonb,
 '{"target_model":"image","enhancement_mode":"detailed","add_negative":true,"language":"en","temperature":0.7,"max_tokens":500}'::jsonb);


-- ============================================================
-- STARTER PIPELINE TEMPLATES
-- ============================================================

INSERT INTO templates (
    workspace_id, created_by, name, description,
    category, tags, difficulty,
    graph_data, input_schema, example_inputs,
    is_public, is_official
) VALUES

(NULL, '00000000-0000-0000-0000-000000000001',
 'Image Generation Pipeline',
 'Enhance a raw prompt with ChatGPT then generate with Flux Pro 1.1 Ultra',
 'image', ARRAY['image','flux','prompt-enhancement'], 'beginner',
 '{"nodes":[{"id":"n1","node_type":"prompt_enhancer","label":"Enhance Prompt","model":"gpt-4o-prompt-enhancer"},{"id":"n2","node_type":"ai_generate","label":"Generate Image","model":"flux-pro-1.1-ultra"}],"edges":[{"source":"n1","source_port":"enhanced_prompt","target":"n2","target_port":"prompt"}]}'::jsonb,
 '{"properties":{"raw_prompt":{"type":"string","title":"Your Prompt"}}}'::jsonb,
 '{"raw_prompt":"a futuristic city at night with neon reflections on wet streets"}'::jsonb,
 TRUE, TRUE),

(NULL, '00000000-0000-0000-0000-000000000001',
 'Text to Video Pipeline',
 'Enhance prompt with Gemini then generate a video with Veo 3',
 'video', ARRAY['video','veo3','prompt-enhancement','gemini'], 'beginner',
 '{"nodes":[{"id":"n1","node_type":"prompt_enhancer","label":"Enhance Prompt","model":"gemini-2.0-flash-prompt-enhancer"},{"id":"n2","node_type":"ai_generate","label":"Generate Video","model":"veo-3"}],"edges":[{"source":"n1","source_port":"enhanced_prompt","target":"n2","target_port":"prompt"}]}'::jsonb,
 '{"properties":{"raw_prompt":{"type":"string","title":"Describe your video"}}}'::jsonb,
 '{"raw_prompt":"a drone shot sweeping over a mountain range at golden hour"}'::jsonb,
 TRUE, TRUE),

(NULL, '00000000-0000-0000-0000-000000000001',
 'Image to Video Pipeline',
 'Generate an image with Imagen 4 then animate it with Runway Gen-4',
 'video', ARRAY['image-to-video','imagen4','runway'], 'intermediate',
 '{"nodes":[{"id":"n1","node_type":"prompt_enhancer","label":"Enhance Prompt","model":"gpt-4o-prompt-enhancer"},{"id":"n2","node_type":"ai_generate","label":"Generate Image","model":"imagen-4"},{"id":"n3","node_type":"ai_generate","label":"Animate","model":"gen-4"}],"edges":[{"source":"n1","source_port":"enhanced_prompt","target":"n2","target_port":"prompt"},{"source":"n2","source_port":"image","target":"n3","target_port":"image_url"}]}'::jsonb,
 '{"properties":{"raw_prompt":{"type":"string","title":"Describe your scene"}}}'::jsonb,
 '{"raw_prompt":"a lone astronaut standing on the surface of Mars at sunset"}'::jsonb,
 TRUE, TRUE),

(NULL, '00000000-0000-0000-0000-000000000001',
 'Video Upscale Pipeline',
 'Generate a video with Kling v2 then enhance and upscale with Topaz',
 'video', ARRAY['upscale','topaz','kling','enhancement'], 'intermediate',
 '{"nodes":[{"id":"n1","node_type":"prompt_enhancer","label":"Enhance Prompt","model":"gemini-2.0-flash-prompt-enhancer"},{"id":"n2","node_type":"ai_generate","label":"Generate Video","model":"kling-v2"},{"id":"n3","node_type":"ai_enhance","label":"Upscale","model":"topaz-video-ai"}],"edges":[{"source":"n1","source_port":"enhanced_prompt","target":"n2","target_port":"prompt"},{"source":"n2","source_port":"video","target":"n3","target_port":"video_url"}]}'::jsonb,
 '{"properties":{"prompt":{"type":"string","title":"Video Prompt"}}}'::jsonb,
 '{"prompt":"a timelapse of storm clouds rolling over a city skyline"}'::jsonb,
 TRUE, TRUE),

(NULL, '00000000-0000-0000-0000-000000000001',
 'Multi-Model Video Comparison',
 'Send the same prompt to Sora, Runway Gen-4, and Luma Ray 2 in parallel then compare',
 'video', ARRAY['comparison','sora','runway','luma','parallel'], 'advanced',
 '{"nodes":[{"id":"n0","node_type":"prompt_enhancer","label":"Enhance","model":"gemini-2.0-flash-prompt-enhancer"},{"id":"n1","node_type":"ai_generate","label":"Sora","model":"sora"},{"id":"n2","node_type":"ai_generate","label":"Runway Gen-4","model":"gen-4"},{"id":"n3","node_type":"ai_generate","label":"Luma Ray 2","model":"ray-2"},{"id":"n4","node_type":"output","label":"Compare Results"}],"edges":[{"source":"n0","source_port":"enhanced_prompt","target":"n1","target_port":"prompt"},{"source":"n0","source_port":"enhanced_prompt","target":"n2","target_port":"prompt"},{"source":"n0","source_port":"enhanced_prompt","target":"n3","target_port":"prompt"},{"source":"n1","source_port":"video","target":"n4","target_port":"video_a"},{"source":"n2","source_port":"video","target":"n4","target_port":"video_b"},{"source":"n3","source_port":"video","target":"n4","target_port":"video_c"}]}'::jsonb,
 '{"properties":{"raw_prompt":{"type":"string","title":"Describe your video"}}}'::jsonb,
 '{"raw_prompt":"slow motion ocean wave crashing on a rocky cliff at sunrise"}'::jsonb,
 TRUE, TRUE);

-- ============================================================
-- END OF MODEL REGISTRY SEED
-- ============================================================
