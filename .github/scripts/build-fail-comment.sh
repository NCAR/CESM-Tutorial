# shopt setting here makes the `logs=` line below return an empty array if no matches
shopt -s nullglob

# Using an array here avoids issues with `wc -w` where filenames have spaces.
# This runs inside the directory download-artifact extracted into. A lone artifact lands
# straight in that directory and nests under <artifact-name>/ only when the run uploaded
# more than one. Accept both.
logs=(*/"${LOGFILE_BASENAME}")
if [[ -f "${LOGFILE_BASENAME}" ]]; then
  logs+=("${LOGFILE_BASENAME}")
fi
if (( ${#logs[@]} == 0 )); then
  echo "::error::No build log in artifacts; nothing to post."
  exit 2
elif (( ${#logs[@]} > 1 )); then
  echo "::error::Expected 1 build log; found ${#logs[@]}: ${logs[*]}"
  exit 3
fi

# Keep the tail: sphinx prints its warning summary at the end.
log_bytes=$(wc -c < "${logs[0]}" | tr -d " ")
truncated=false
if (( log_bytes > MAX_LOG_BYTES )); then
  truncated=true
fi

# Generate the message
{
  echo "### ❌ jupyter-book build failed"
  echo
  if [[ "$truncated" == true ]]; then
    echo "> ⚠️ Log was ${log_bytes} bytes; only the last ${MAX_LOG_BYTES} are shown below. See the [workflow run](${RUN_URL}) for the full log."
    echo
  fi
  echo '<details open="true">'
  echo "<summary>Build logs</summary>"
  echo
  # Four backticks so a ``` inside the log can't close the fence early.
  echo '````'
  tail -c "$MAX_LOG_BYTES" "${logs[0]}"
  # Make sure the closing fence starts on its own line even if the log lacks a trailing newline.
  echo
  echo '````'
  echo
  echo "</details>"
  echo
  # Add explanation for "document isn't included in any toctree" issue
  if grep -qF "document isn't included in any toctree" "${logs[0]}"; then
    cat <<'EOF'
> [!TIP]
> To resolve "document isn't included in any toctree" error(s), either:
> * Add the relevant file(s) to `_toc.yml`, or
> * Delete them, or
> * Add them to `exclude_paths` in `_config.yml`.
EOF
  fi
  echo
} > comment-body.md
gh pr comment "$PR_NUMBER" --repo "$REPO" --body-file comment-body.md
