# decK

`config/ai.yaml` is applied with decK (v1.68.0 or later).

1. Download the decK archive for your OS from the same place as the image files.
2. Verify it: `shasum -a 256 -c SHA256SUMS --ignore-missing`.
3. Extract and put `deck` on your PATH: `tar -xzf deck_*_linux_amd64.tar.gz deck && sudo mv deck /usr/local/bin/`.
4. Check: `deck version`.
