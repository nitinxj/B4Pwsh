B4Pwsh is a profile‑driven bash shell UX layer on top of PowerShell, with a dedicated parser, history engine, and config stack that preserve bash muscle memory while executing pure PowerShell under the hood - _Bash-compatible shell for PowerShell_

## 🚀 v1.0 Live (Feb 2026)

1. ✅ Core shell loop + custom prompt 
2. ✅ Multiple Bash commands: ls/ps/grep/head/tail/rm/cd/cat/history/!! 
3. ✅ Pipe chains: ls | grep ps1 | head -5 
4. ✅ Profiles: .profile → .b4pwsh_profile → .b4pwsh_rc 
5. ✅ Config: vi mode, translation toggle, aliases 
6. ✅ History persistence 
7. ✅ Multi-statement: config; ls | grep ps1`

⚡ Install (30 Seconds)
1. Clone git clone https://github.com/nitinxj/B4Pwsh.git ~/B4Pwsh 
2. Enter + load cd ~/B4Pwsh . ./B4Pwsh.ps1 
3. Run shell b4pwsh
    Permanent: Add to $PROFILE 
    notepad $PROFILE 
    Add: . ~/B4Pwsh/B4Pwsh.ps1

## 📈 Architecture (10k ft)
`Input → Parser (Bash→PS) → Exec → Rich Objects → Prompt        ↑ Profiles/History/Aliases ↑ Config`

🤝 Few Examples

1. ll                    # ls -la
2. history | tail -3     # Recent cmds
3. alias ll='ls -la'     # Persists
4. config vi on          # Vi editing

⭐ Star if it works for Enterprise Automation

**Cloud IT Leaders**—**your feedback drives v1.1** (Ctrl+R, git suite).

**LinkedIn**: [nitinxj](https://linkedin.com/in/nitinxj) | **Fork/Star/PRs welcome!**
