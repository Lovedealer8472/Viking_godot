import torch
import os, sys
from diffusers import DiffusionPipeline

MODEL = "stabilityai/stable-diffusion-xl-base-1.0"

print("Loading SDXL from HuggingFace...")
pipe = DiffusionPipeline.from_pretrained(
    MODEL,
    torch_dtype=torch.float16,
    use_safetensors=True,
    variant="fp16",
)
pipe = pipe.to("cuda")
print(f"Loaded on {torch.cuda.get_device_name()}")

S = "dark norse illustration, painterly concept art, strong chiaroscuro, deep shadows, muted earth tones, gold highlights, Banner Saga Darkest Dungeon art style, storybook quality"
N = "photorealistic, 3d render, glossy, anime, cartoon, bright, cheerful, text, watermark"

jobs = [
    ("fjord", "assets/art/scenes/fjord.png", 1024, 576, f"Wide norwegian fjord, misty mountains, viking knarr at dock, overcast, dark water, {S}"),
    ("hall", "assets/art/scenes/hall.png", 1024, 576, f"Viking longhouse interior, fire pit, shields on walls, warm firelight, long tables, {S}"),
    ("ship_deck", "assets/art/scenes/ship_deck.png", 1024, 576, f"Viking knarr ship deck, low angle toward dragon prow, stormy sky, dark sea, {S}"),
    ("leader", "assets/art/characters/leader.png", 512, 896, f"Norse leader portrait, 32, bearded, fur cloak, ship tiller, dramatic light, {S}"),
    ("bjarne", "assets/art/characters/bjarne.png", 512, 896, f"Norse fighter portrait, broad, facial scar, bearded axe, leather armor, {S}"),
    ("ragna", "assets/art/characters/ragna.png", 512, 896, f"Norse woman portrait, strong, braided hair, wool dress, weathered face, {S}"),
    ("einar", "assets/art/characters/einar.png", 512, 896, f"Norse scholar portrait, thin gaunt, pale eyes, grey hair, rune sticks, {S}"),
    ("brynja", "assets/art/characters/brynja.png", 512, 896, f"Norse craftswoman portrait, leather apron, tools, keen gaze, {S}"),
    ("leif", "assets/art/characters/leif.png", 512, 896, f"Norse scout portrait, lean, alert eyes, short bow, hooded cloak, {S}"),
    ("jarl", "assets/art/characters/jarl.png", 512, 896, f"Young norse boy portrait, 14, eager eyes, oversized tunic, hopeful, {S}"),
]

os.makedirs("assets/art/scenes", exist_ok=True)
os.makedirs("assets/art/characters", exist_ok=True)

for name, path, w, h, prompt in jobs:
    if os.path.exists(path):
        print(f"SKIP {name}")
        continue
    print(f"{name} ({w}x{h})...", end=" ", flush=True)
    img = pipe(prompt=prompt, negative_prompt=N, width=w, height=h, num_inference_steps=25, guidance_scale=7).images[0]
    img.save(path)
    print("OK")

print("Done!")
