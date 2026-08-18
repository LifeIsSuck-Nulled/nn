"""
LABA HUB — Discord Bot Bridge  (Cloud Phone / Remote Edition)
────────────────────────────────────────────────────────────────
Commands:
  !upgrades          — show all PCs + possible upgrades from inventory
  !customize <num>   — queue upgrade for that PC
  !customize all     — queue upgrade for every upgradeable PC
  !refresh           — ask Roblox executor to re-fetch inventory & PC state
  !pcs               — alias for !upgrades

Setup (Termux on cloud phone):
  pkg update && pkg upgrade
  pkg install python
  pip install discord.py flask

  Then in a SECOND Termux session, expose port 5000:
    Option A (easiest, no install):
      ssh -R 80:localhost:5000 serveo.net
      → copy the URL it gives, e.g. https://abc123.serveo.net

    Option B (ngrok):
      pkg install tsu && su -c "pkg install ngrok"
      ngrok http 5000
      → copy the https://xxxx.ngrok-free.app URL

  Paste that URL into BOT_URL in laba_bridge.lua (no trailing slash).

  Set BOT_TOKEN and SECRET_KEY below, then: python bot.py
────────────────────────────────────────────────────────────────
"""

import discord
from discord.ext import commands
import threading
import json
from flask import Flask, request as freq, jsonify
import asyncio
import time

BOT_TOKEN  = "YOUR_BOT_TOKEN_HERE"   # ← paste your bot token here
SECRET_KEY = "labahub_secret_123"     # ← change this, must match Lua script
PORT       = 5000                     # Flask listens on this port

# ── Shared state (Flask thread writes, Discord thread reads) ─────────────────
state_lock = threading.Lock()
state = {
    "pcs":         [],      # list of PC dicts pushed by executor
    "last_push":   None,    # timestamp string from executor
    "pending_cmd": None,    # command waiting for executor to pick up
    "result_queue": [],     # results posted back by executor
}

# ── Flask HTTP server (Roblox executor talks to this) ────────────────────────
flask_app = Flask(__name__)

def check_secret():
    """Return True if the request carries the correct secret key."""
    return freq.headers.get("X-Secret") == SECRET_KEY

@flask_app.route("/update", methods=["POST"])
def route_update():
    """Executor pushes PC data here."""
    if not check_secret():
        return jsonify({"error": "unauthorized"}), 403
    data = freq.get_json(force=True) or {}
    with state_lock:
        state["pcs"]       = data.get("pcs", [])
        state["last_push"] = data.get("timestamp", "unknown")
    return jsonify({"ok": True})

@flask_app.route("/command", methods=["GET"])
def route_command():
    """Executor polls here for pending commands. Command is cleared after read."""
    if not check_secret():
        return jsonify({"error": "unauthorized"}), 403
    with state_lock:
        cmd = state["pending_cmd"]
        state["pending_cmd"] = None
    return jsonify({"command": cmd})

@flask_app.route("/result", methods=["POST"])
def route_result():
    """Executor posts back the result after applying an upgrade."""
    if not check_secret():
        return jsonify({"error": "unauthorized"}), 403
    data = freq.get_json(force=True) or {}
    with state_lock:
        state["result_queue"].append(data)
    return jsonify({"ok": True})

def run_flask():
    # 0.0.0.0 = accept connections from anywhere (needed for tunnel / cloud phone)
    flask_app.run(host="0.0.0.0", port=PORT, debug=False, use_reloader=False)

threading.Thread(target=run_flask, daemon=True).start()

# ── Discord bot ───────────────────────────────────────────────────────────────
intents = discord.Intents.default()
intents.message_content = True
bot = commands.Bot(command_prefix="!", intents=intents)

def _pc_embed(pcs: list) -> discord.Embed:
    """Build the upgrade report embed from PC list."""
    can_upgrade = [p for p in pcs if p.get("upgrades")]
    maxed_out   = [p for p in pcs if not p.get("upgrades")]

    # Sort upgradeable by gain descending
    can_upgrade.sort(key=lambda p: p.get("gain", 0), reverse=True)

    embed = discord.Embed(
        title="🖥️  PC Upgrade Report",
        color=0x5B9CF6,
    )

    if can_upgrade:
        lines = []
        for pc in can_upgrade:
            num  = pc["num"]
            cur  = pc["current_hr"]
            pot  = pc["potential_hr"]
            gain = pc["gain"]
            parts = "  |  ".join(
                f"{u['slot']}: {u['from']} → **{u['to']}** (+{u['gain']}/hr)"
                for u in pc["upgrades"]
            )
            lines.append(
                f"**PC {num}** — {cur}/hr → **{pot}/hr** (+{gain}/hr)\n"
                f"┗ {parts}"
            )
        embed.add_field(
            name=f"⬆️  Can Be Upgraded ({len(can_upgrade)} PCs)",
            value="\n\n".join(lines),
            inline=False,
        )

    if maxed_out:
        nums = "  ".join(f"PC {p['num']}" for p in maxed_out)
        embed.add_field(
            name=f"✅  Already Best ({len(maxed_out)} PCs)",
            value=nums,
            inline=False,
        )

    total_gain = sum(p.get("gain", 0) for p in pcs)
    embed.set_footer(text=f"Total potential gain: +{total_gain}/hr  •  !customize <num> to apply")
    return embed


def _queue_cmd(cmd: dict):
    with state_lock:
        state["pending_cmd"] = cmd


def _get_pc(num: str):
    with state_lock:
        return next((p for p in state["pcs"] if str(p["num"]) == str(num)), None)


def _get_pcs():
    with state_lock:
        return list(state["pcs"])


# ── Commands ──────────────────────────────────────────────────────────────────

@bot.command(name="upgrades", aliases=["pcs", "status"])
async def cmd_upgrades(ctx):
    """Show all PCs and their possible upgrades."""
    pcs = _get_pcs()
    if not pcs:
        await ctx.send(
            "❌ No data received yet.\n"
            "Make sure your Roblox executor is running and `laba_bridge.lua` is loaded."
        )
        return
    embed = _pc_embed(pcs)
    await ctx.send(embed=embed)


@bot.command(name="customize")
async def cmd_customize(ctx, *, target: str = None):
    """
    !customize <PC number>   — upgrade one PC
    !customize all           — upgrade every upgradeable PC
    """
    if not target:
        await ctx.send("Usage: `!customize <PC number>` or `!customize all`")
        return

    pcs = _get_pcs()
    if not pcs:
        await ctx.send("❌ No PC data yet. Run the executor first.")
        return

    if target.strip().lower() == "all":
        upgradeable = [p for p in pcs if p.get("upgrades")]
        if not upgradeable:
            await ctx.send("✅ All PCs are already at their best!")
            return
        _queue_cmd({"action": "customize_all"})
        total_gain = sum(p["gain"] for p in upgradeable)
        embed = discord.Embed(
            title="⚙️  Queued: Upgrade All PCs",
            description=(
                f"**{len(upgradeable)} PCs** will be upgraded.\n"
                f"Total gain: **+{total_gain}/hr**\n\n"
                "Executor will apply these on next poll."
            ),
            color=0x57F287,
        )
        await ctx.send(embed=embed)
        return

    # Single PC
    pc = _get_pc(target.strip())
    if not pc:
        nums = ", ".join(str(p["num"]) for p in pcs)
        await ctx.send(f"❌ PC {target} not found. Available: {nums}")
        return

    if not pc.get("upgrades"):
        await ctx.send(f"✅ PC {target} is already equipped with the best parts you own!")
        return

    _queue_cmd({"action": "customize", "pc": str(pc["num"])})

    lines = [
        f"• {u['slot']}: **{u['from']}** → **{u['to']}** (+{u['gain']}/hr)"
        for u in pc["upgrades"]
    ]
    embed = discord.Embed(
        title=f"⚙️  Queued: Customize PC {pc['num']}",
        description="\n".join(lines),
        color=0x57F287,
    )
    embed.add_field(
        name="Earnings",
        value=f"{pc['current_hr']}/hr → **{pc['potential_hr']}/hr** (+{pc['gain']}/hr)",
    )
    embed.set_footer(text="Executor will apply this on next poll (~3s).")
    await ctx.send(embed=embed)


@bot.command(name="refresh")
async def cmd_refresh(ctx):
    """Ask the executor to re-fetch inventory and PC state."""
    _queue_cmd({"action": "refresh"})
    await ctx.send("🔄 Sent refresh request. Updated data will appear in ~10s.")


@bot.command(name="pc")
async def cmd_pc(ctx, num: str = None):
    """Show details for a single PC."""
    if not num:
        await ctx.send("Usage: `!pc <number>`")
        return
    pc = _get_pc(num)
    if not pc:
        await ctx.send(f"❌ PC {num} not found.")
        return

    embed = discord.Embed(
        title=f"🖥️  PC {pc['num']}",
        color=0x5B9CF6 if pc.get("upgrades") else 0x57F287,
    )
    # Current parts
    lines = [f"• {s['slot']}: {s['name']} ({s['hr']}/hr)" for s in pc.get("parts", [])]
    embed.add_field(name="Currently Equipped", value="\n".join(lines) or "(none)", inline=False)
    # Upgrades
    if pc.get("upgrades"):
        up = [f"• {u['slot']}: {u['from']} → **{u['to']}** (+{u['gain']}/hr)" for u in pc["upgrades"]]
        embed.add_field(name="⬆️  Possible Upgrades", value="\n".join(up), inline=False)
        embed.add_field(name="Earnings", value=f"{pc['current_hr']}/hr → **{pc['potential_hr']}/hr** (+{pc['gain']}/hr)")
    else:
        embed.add_field(name="Status", value=f"✅ Best possible — **{pc['current_hr']}/hr**")
    await ctx.send(embed=embed)


@bot.event
async def on_ready():
    print(f"[Bot] Logged in as {bot.user}  |  Flask on http://127.0.0.1:{PORT}")


# ── Result notifier (polls result_queue and sends to last used channel) ───────
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
            results = list(state["result_queue"])
            state["result_queue"].clear()
        if results and last_channel:
            for r in results:
                pc_num  = r.get("pc", "?")
                before  = r.get("before_hr", "?")
                after   = r.get("after_hr", "?")
                success = r.get("success", False)
                if success:
                    embed = discord.Embed(
                        title=f"✅  PC {pc_num} Upgraded!",
                        description=f"{before}/hr → **{after}/hr** (+{after - before}/hr)",
                        color=0x57F287,
                    )
                else:
                    embed = discord.Embed(
                        title=f"❌  PC {pc_num} — No Changes",
                        description=r.get("reason", "Already at best or failed."),
                        color=0xED4245,
                    )
                await last_channel.send(embed=embed)


async def main():
    async with bot:
        bot.loop.create_task(notify_results())
        await bot.start(BOT_TOKEN)

asyncio.run(main())
