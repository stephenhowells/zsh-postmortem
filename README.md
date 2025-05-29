# zsh-postmortem

> Automatic "why did that just fail?" powered by your favorite LLM
>
> ⚠️ This plugin may still be unstable and may not work reliably yet. It's a work in progress. Feel free to test it out and contribute!

A Zsh plugin that automatically analyzes failed commands and provides AI-powered explanations and solutions. Never wonder why a command failed again!

## ✨ Features

- **Automatic Analysis**: Detects when commands fail (non-zero exit codes) and automatically explains why
- **AI-Powered**: Uses [aichat](https://github.com/sigoden/aichat) to provide intelligent explanations and solutions
- **Smart Caching**: Remembers previous failures to avoid redundant API calls
- **Context-Aware**: Includes command, exit code, working directory, and git branch information
- **Log Browsing**: Browse previous failures with `fzf` integration
- **Configurable**: Customize behavior with environment variables

## 🚀 Installation

### 1. Install the runtime dependencies

- **aichat** - Required for AI analysis

  ```bash
  # Install aichat (see https://github.com/sigoden/aichat for more information)

  brew install aichat # or your package manager of choice
  ```

  The `aichat` tool requires an API key for an LLM. Consult the [aichat repository](https://github.com/sigoden/aichat) for more information.

- **fzf** - Optional, for browsing failure logs

  ```bash
  brew install fzf # or your package manager of choice
  ```

### 2. Grab the plugin

<details>
<summary>Antidote</summary>

```zsh
antidote bundle stephenhowells/zsh-postmortem
```

</details>

<details>
<summary>Oh-My-Zsh</summary>

Clone into `~/.oh-my-zsh/custom/plugins` and add `zsh-postmortem` to the `plugins=(...)` array in `.zshrc`.

```zsh
git clone https://github.com/stephenhowells/zsh-postmortem ~/.oh-my-zsh/custom/plugins/zsh-postmortem
```

</details>

<details>
<summary>Zinit</summary>

```zsh
zinit light stephenhowells/zsh-postmortem
```

</details>

<details>
<summary>Manual (no plugin manager)</summary>

Clone the repo anywhere (for example `~/.zsh/zsh-postmortem`) and source the plugin file from your `.zshrc`:

```zsh
# Grab the plugin
git clone https://github.com/stephenhowells/zsh-postmortem ~/.zsh/zsh-postmortem

# Add to your .zshrc
source ~/.zsh/zsh-postmortem/zsh-postmortem.plugin.zsh
```

</details>

## ⚙️ Configuration

Configure the plugin by setting environment variables in your `.zshrc` before loading the plugin:

```bash
# Disable the plugin entirely
export AI_POSTMORTEM_DISABLE=1

# Cache directory (default: $XDG_STATE_HOME/ai-postmortem or ~/.local/state/ai-postmortem)
export AI_POSTMORTEM_CACHE_DIR="$HOME/.cache/ai-postmortem"

# Model arguments passed to aichat (default: --no-stream)
export AI_POSTMORTEM_MODEL_ARGS="--no-stream --model gpt-4"

# Format output as bullet points (default: true)
export AI_POSTMORTEM_BULLETS=false
```

## 📖 Usage

The plugin works automatically. When a command fails, it will:

1. Capture the command, exit code, and context
2. Check if this failure has been seen before (cached)
3. If new, send the information to your configured LLM
4. Display the explanation and cache it for future reference

### Example Output

```text
$ cat missing_file.txt

cat: missing_file.txt: No such file or directory

✖  cat missing_file.txt
- **Reason for Failure:**
  - The command `cat missing_file.txt` failed because `missing_file.txt` does not exist in the specified directory `/Users/<your-username>`.

- **Exit Code:**
  - An exit code of `1` generally indicates that a file was not found or a general error occurred.

- **How to Fix:**
  - Ensure `missing_file.txt` actually exists by checking the directory listing using `ls` or `find`.
  - Verify you're in the correct directory. Use `pwd` to confirm your current directory and `cd /path/to/correct/directory` if necessary.
  - If the file is in another directory, specify the correct path: `cat /path/to/missing_file.txt`.
  - If the file does not exist, create it using `touch missing_file.txt` before attempting to read it.
```

### Browse Previous Failures

Use the `ai-oops-log` command (or alias `aplo`) to browse previous failures with fzf:

```bash
$ ai-oops-log

# or

$ aplo
```

This opens an interactive browser where you can search and view previous failure explanations.

## 🛠️ How Does This Plugin Work?

1. **Hook Registration**: Uses Zsh's `precmd` hook to run after each command
2. **Failure Detection**: Checks the exit code of the last command
3. **Context Gathering**: Collects command text, exit code, working directory, and git branch
4. **Deduplication**: Creates a hash of the failure context to avoid duplicate API calls
5. **AI Analysis**: Sends context to `aichat` for analysis
6. **Caching**: Stores results for future identical failures

## 🔒 Privacy

- **Local Processing**: All analysis happens through your local `aichat` configuration
- **No Data Collection**: The plugin doesn't send data anywhere except through your configured LLM
- **Cached Results**: Previous analyses are stored locally in your cache directory
- **Configurable**: You control which LLM service is used via `aichat` configuration

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📄 License

MIT License - see [LICENSE](LICENSE) file for details.
