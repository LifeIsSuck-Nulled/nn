"""
LABA HUB — Discord Bot Bridge  (Multi-User Edition)
────────────────────────────────────────────────────────────────
Commands:
  !link <code>       — link your Discord to your Roblox session
  !upgrades          — show YOUR PCs + upgrades
  !customize <num>   — upgrade one of YOUR PCs
  !customize all     — upgrade all of YOUR upgradeable PCs
  !refresh           — re-fetch your inventory & PC state
  !unlink            — unlink your Discord from Roblox

Setup (Termux):
  pkg install python openssh
  pip install discord.py flask
  python bots.py
────────────────────────────────────────────────────────────────
"""

import discord
from discord.ext import commands
import threading
from flask import Flask, request as freq, jsonify
import asyncio
import subprocess
import re

BOT_TOKEN  = input("Enter bot token: ")
SECRET_KEY = "labahub_secret_123"
PORT       = 5000

# ── Auto-tunnel ───────────────────────────────────────────────────────────────
_tunnel_url = None
_tunnel_ready = threading.Event()

def _try_tunnel(cmd, pattern):
    global _tunnel_url
    try:
        proc = subprocess.Popen(
            cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True
        )
        for line in proc.stdout:
            m = re.search(pattern, line)
            if m:
                _tunnel_url = m.group().strip().rstrip('/')
                print(f"\n{'='*60}\n  PUBLIC URL: {_tunnel_url}\n{'='*60}\n")
                _tunnel_ready.set()
                proc.stdout.read()  # keep alive
    except Exception as e:
        print(f"Tunnel error: {e}")

def _run_tunnel():
    # Try serveo first, then localhost.run as fallback
    import time
    for cmd, pattern in [
        (["ssh", "-o", "StrictHostKeyChecking=no", "-o", "ServerAliveInterval=30",
          "-R", f"80:localhost:{PORT}", "serveo.net"], r'https://\S+'),
        (["ssh", "-o", "StrictHostKeyChecking=no", "-o", "ServerAliveInterval=30",
          "-R", f"80:localhost:{PORT}", "nokey@localhost.run"], r'https://\S+'),
    ]:
        if _tunnel_url:
            break
        t = threading.Thread(target=_try_tunnel, args=(cmd, pattern), daemon=True)
        t.start()
        t.join(timeout=15)
        if _tunnel_url:
            break
        print("Trying next tunnel provider...")

threading.Thread(target=_run_tunnel, daemon=True).start()
print("Waiting for tunnel...")
_tunnel_ready.wait(timeout=40)
if not _tunnel_url:
    print("WARNING: No tunnel started. Update BOT_URL in Lua script manually with your IP.")

# ── Shared state ──────────────────────────────────────────────────────────────
state_lock = threading.Lock()
# sessions: code -> { pcs, username, last_push }
# linked:   discord_user_id -> code
# cmds:     code -> pending command
# results:  list of { code, ... }
state = {
    "sessions": {},
    "linked":   {},
    "cmds":     {},
    "results":  [],
}

# ── Flask routes ──────────────────────────────────────────────────────────────
flask_app = Flask(__name__)

def check_secret():
    return freq.headers.get("X-Secret") == SECRET_KEY

@flask_app.route("/update", methods=["POST"])
def route_update():
    if not check_secret():
        return jsonify({"error": "unauthorized"}), 403
    data = freq.get_json(force=True) or {}
    code = data.get("code")
    if not code:
        return jsonify({"error": "missing code"}), 400
    with state_lock:
        state["sessions"][code] = {
            "pcs":       data.get("pcs", []),
            "username":  data.get("username", "Unknown"),
            "last_push": data.get("timestamp", "?"),
        }
    return jsonify({"ok": True})

@flask_app.route("/command", methods=["GET"])
def route_command():
    if not check_secret():
        return jsonify({"error": "unauthorized"}), 403
    code = freq.args.get("code")
    if not code:
        return jsonify({"command": None})
    with state_lock:
        cmd = state["cmds"].pop(code, None)
    return jsonify({"command": cmd})

@flask_app.route("/result", methods=["POST"])
def route_result():
    if not check_secret():
        return jsonify({"error": "unauthorized"}), 403
    data = freq.get_json(force=True) or {}
    with state_lock:
        state["results"].append(data)
    return jsonify({"ok": True})

threading.Thread(target=lambda: flask_app.run(host="0.0.0.0", port=PORT, debug=False, use_reloader=False), daemon=True).start()

# ── Discord bot ───────────────────────────────────────────────────────────────
intents = discord.Intents.default()
intents.message_content = True
bot = commands.Bot(command_prefix="!", intents=intents)

def _get_code_for(discord_id):
    with state_lock:
        return state["linked"].get(str(discord_id))

def _get_session(code):
    with state_lock:
        return state["sessions"].get(code)

def _queue_cmd(code, cmd):
    with state_lock:
        state["cmds"][code] = cmd

def _build_pc_embed(pc):
    has_up = bool(pc.get("upgrades"))
    embed = discord.Embed(
        title=f"🖥️  PC {pc['num']}",
        color=0x5B9CF6 if has_up else 0x57F287,
    )
    parts = [f"`{s['slot']}` — {s['name']} ({s['hr']}/hr)" for s in pc.get("parts", [])]
    if parts:
        embed.add_field(name="Currently Equipped", value="\n".join(parts), inline=False)
    if has_up:
        ups = [f"⬆️ `{u['slot']}` {u['from']} → **{u['to']}** (+{u['gain']}/hr)" for u in pc["upgrades"]]
        embed.add_field(name="Recommended Upgrades", value="\n".join(ups), inline=False)
        embed.add_field(name="Earnings After Upgrade",
            value=f"{pc['current_hr']}/hr → **{pc['potential_hr']}/hr** (+{pc['gain']}/hr)", inline=False)
    else:
        embed.add_field(name="Status", value=f"✅ Already best — **{pc['current_hr']}/hr**", inline=False)
    return embed

class UpgradeView(discord.ui.View):
    def __init__(self, code, pc_num, has_upgrades):
        super().__init__(timeout=300)
        self.code   = code
        self.pc_num = pc_num
        btn = discord.ui.Button(
            label=f"⚙️ Upgrade PC {pc_num}",
            style=discord.ButtonStyle.green if has_upgrades else discord.ButtonStyle.grey,
            disabled=not has_upgrades,
        )
        btn.callback = self.on_click
        self.add_item(btn)

    async def on_click(self, interaction: discord.Interaction):
        session = _get_session(self.code)
        if not session:
            await interaction.response.send_message("❌ Session expired. Re-run the executor.", ephemeral=True)
            return
        pc = next((p for p in session["pcs"] if str(p["num"]) == str(self.pc_num)), None)
        if not pc or not pc.get("upgrades"):
            await interaction.response.send_message(f"✅ PC {self.pc_num} already at best!", ephemeral=True)
            return
        _queue_cmd(self.code, {"action": "customize", "pc": str(self.pc_num)})
        await interaction.response.send_message(f"⚙️ Queued upgrade for **PC {self.pc_num}**...", ephemeral=True)

# ── Commands ──────────────────────────────────────────────────────────────────

@bot.command(name="link")
async def cmd_link(ctx, code: str = None):
    """Link your Discord to your Roblox session code."""
    if not code:
        await ctx.send("Usage: `!link <code>`\nGet your code from the Roblox executor console.")
        return
    code = code.upper().strip()
    session = _get_session(code)
    if not session:
        await ctx.send(f"❌ Code `{code}` not found. Make sure your executor script is running.")
        return
    with state_lock:
        state["linked"][str(ctx.author.id)] = code
    await ctx.send(f"✅ Linked! Welcome **{session['username']}** — use `!upgrades` to see your PCs.")

@bot.command(name="unlink")
async def cmd_unlink(ctx):
    """Unlink your Discord from Roblox."""
    with state_lock:
        state["linked"].pop(str(ctx.author.id), None)
    await ctx.send("✅ Unlinked.")

@bot.command(name="upgrades", aliases=["pcs", "status"])
async def cmd_upgrades(ctx):
    """Show your PCs with upgrade buttons."""
    code = _get_code_for(ctx.author.id)
    if not code:
        await ctx.send("❌ Not linked yet. Run the executor script and use `!link <code>`.")
        return
    session = _get_session(code)
    if not session:
        await ctx.send("❌ Session not found. Make sure your executor script is running.")
        return
    pcs = session["pcs"]
    if not pcs:
        await ctx.send("❌ No PC data yet. Wait a moment and try again.")
        return

    upgradeable = sorted([p for p in pcs if p.get("upgrades")], key=lambda p: p.get("gain", 0), reverse=True)
    maxed       = [p for p in pcs if not p.get("upgrades")]

    await ctx.send(f"📋 **{session['username']}'s PCs** — {len(upgradeable)} can upgrade, {len(maxed)} maxed out")
    for pc in upgradeable + maxed:
        embed = _build_pc_embed(pc)
        view  = UpgradeView(code, str(pc["num"]), bool(pc.get("upgrades")))
        await ctx.send(embed=embed, view=view)

@bot.command(name="customize")
async def cmd_customize(ctx, *, target: str = None):
    """!customize <PC number>  or  !customize all"""
    code = _get_code_for(ctx.author.id)
    if not code:
        await ctx.send("❌ Not linked. Use `!link <code>` first.")
        return
    session = _get_session(code)
    if not session:
        await ctx.send("❌ Session not found. Run your executor script.")
        return
    if not target:
        await ctx.send("Usage: `!customize <PC number>` or `!customize all`")
        return

    pcs = session["pcs"]
    if target.strip().lower() == "all":
        upgradeable = [p for p in pcs if p.get("upgrades")]
        if not upgradeable:
            await ctx.send("✅ All your PCs are already maxed out!")
            return
        _queue_cmd(code, {"action": "customize_all"})
        total = sum(p["gain"] for p in upgradeable)
        await ctx.send(f"⚙️ Queued upgrade for **{len(upgradeable)} PCs** — total gain +{total}/hr")
        return

    pc = next((p for p in pcs if str(p["num"]) == target.strip()), None)
    if not pc:
        nums = ", ".join(str(p["num"]) for p in pcs)
        await ctx.send(f"❌ PC {target} not found. Available: {nums}")
        return
    if not pc.get("upgrades"):
        await ctx.send(f"✅ PC {target} already at best!")
        return
    _queue_cmd(code, {"action": "customize", "pc": str(pc["num"])})
    await ctx.send(f"⚙️ Queued upgrade for **PC {target}**!")

@bot.command(name="refresh")
async def cmd_refresh(ctx):
    """Re-fetch your inventory and PC state."""
    code = _get_code_for(ctx.author.id)
    if not code:
        await ctx.send("❌ Not linked. Use `!link <code>` first.")
        return
    _queue_cmd(code, {"action": "refresh"})
    await ctx.send("🔄 Refresh sent — updated data in ~10s.")

@bot.event
async def on_ready():
    print(f"[Bot] Logged in as {bot.user}  |  Flask on :{PORT}")

# ── Result notifier ───────────────────────────────────────────────────────────
last_channel = None

@bot.event
async def on_message(msg):
    global last_channel
    if not msg.author.bot:
        last_channel = msg.channel
    await bot.process_commands(msg)

async def notify_results():
    await bot.wait_until_ready()
    while not bot.is_closed():
        await asyncio.sleep(2)
        with state_lock:
            results = list(state["results"])
            state["results"].clear()
        if results and last_channel:
            for r in results:
                pc_num  = r.get("pc", "?")
                before  = r.get("before_hr", "?")
                after   = r.get("after_hr", "?")
                success = r.get("success", False)
                username = r.get("username", "")
                title = f"✅  PC {pc_num} Upgraded!" if success else f"❌  PC {pc_num} — No Changes"
                desc  = f"{before}/hr → **{after}/hr** (+{after - before}/hr)" if success else r.get("reason", "Already best.")
                embed = discord.Embed(title=title, description=desc,
                    color=0x57F287 if success else 0xED4245)
                if username:
                    embed.set_footer(text=f"Player: {username}")
                await last_channel.send(embed=embed)

async def main():
    async with bot:
        bot.loop.create_task(notify_results())
        await bot.start(BOT_TOKEN)

asyncio.run(main())
