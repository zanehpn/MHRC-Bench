import matplotlib.pyplot as plt
import os
import ast

def read_loss_data(filepath):
    losses = []
    epochs = []
    if not os.path.exists(filepath):
        # Try looking in the script directory
        script_dir = os.path.dirname(os.path.abspath(__file__))
        filepath = os.path.join(script_dir, os.path.basename(filepath))
        if not os.path.exists(filepath):
            print(f"Warning: File {filepath} not found.")
            return epochs, losses
    
    with open(filepath, 'r') as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                # Parse the line as a Python dictionary
                data = ast.literal_eval(line)
                if isinstance(data, dict) and 'loss' in data and 'epoch' in data:
                    losses.append(float(data['loss']))
                    epochs.append(float(data['epoch']))
            except (ValueError, SyntaxError):
                continue
    return epochs, losses

def main():
    files = {
        "ds_5p7b_loss.txt": "DeepSeek 5.7B",
        "qwen_7b_loss.txt": "Qwen 7B",
        "qwen_14b_loss.txt": "Qwen 14B"
    }

    plt.figure(figsize=(10, 6))

    for filename, label in files.items():
        epochs, losses = read_loss_data(filename)
        if losses:
            plt.plot(epochs, losses, label=label, marker='.', markersize=2, linewidth=1)
        else:
            print(f"No valid data found for {label}")
    char_size = 18
    plt.title("Training Loss vs. Epochs", fontsize=char_size)
    plt.xlabel("Epochs", fontsize=char_size)
    plt.ylabel("Loss", fontsize=char_size)
    plt.tick_params(axis='both', which='major', labelsize=char_size - 2)

    plt.legend(fontsize=char_size)
    plt.grid(True)
    
    # Save the plot or show it
    output_path = "loss_comparison.png"
    # Save to script dir if possible
    script_dir = os.path.dirname(os.path.abspath(__file__))
    output_path = os.path.join(script_dir, output_path)
    
    plt.savefig(output_path)
    print(f"Plot saved to {output_path}")
    # plt.show() # Optional

if __name__ == "__main__":
    main()