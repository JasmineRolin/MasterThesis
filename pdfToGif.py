import os
import imageio.v2 as imageio

folder = "tests/WaitingPlots/Gen_Data_100_0.7_1/false_false"

# Case-insensitive filter for filenames not containing "ROUTE"
png_files = [
    f for f in sorted(os.listdir(folder))
    if f.lower().endswith('.png') 
    and "current" in f.lower()
    and "route" not in f.lower()
]
images = []
for png_file in png_files:
    print(f"Processing {png_file}")
    img_path = os.path.join(folder, png_file)
    img = imageio.imread(img_path)
    images.append(img)

output_gif = os.path.join(folder, "gant.gif")
imageio.mimsave(output_gif, images, fps=0.7,loop=0)
print(f"Saved GIF as {output_gif}")
