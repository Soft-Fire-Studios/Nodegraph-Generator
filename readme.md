## Nodegraph Generator

This simple utility is capable of randomly generating nodes across the entirety of any map.

### Instructions
- Navigate to Utilizes > Nodegraph > Generation
- Press "Generate Node Data"
- Once it finishes generating, you can look over the nodes and decide if you want to re-generate or not
- Go to your Garry's Mod directory > data > ch_nodegraph
- Locate the .ain.txt file named after the map you are playing on
- Remove the .txt part
- Move the .aim file to your Garry's Mod directory > maps > graphs
- Type 'restart' in your console
- Type 'ai_show_connect' to verify the nodegraph isn't being overwritten by the map

### Notes
- This utility isn't supposed to create a nodegraph for you, all it does is calculates random/verified positions to place nodes
- This tool is compatible with the 'Nodegraph Editor' tool I made. After you verify your nodegraph saved correctly, you can edit the nodegraph manually with the tool and save the new nodegraph through the tool
- This is a WIP, bugs and improvements will come with time

### To do
- Calculate positions through Nav-Mesh first, then calculate randomly
- Fix any bugs