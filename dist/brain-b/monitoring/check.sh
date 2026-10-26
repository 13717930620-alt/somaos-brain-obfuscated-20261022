#!/bin/bash
DIR="C:/Users/redact/Desktop/大脑项目 - 最新通用版(3)/大脑项目 - 最新通用版(3)/大脑项目 - 最新通用版/大脑项目"
LOG="$DIR/monitoring/hourly.log"
NOW=$(date '+%Y-%m-%d %H:%M:%S')

HEALTH=$(curl -s http://localhost:3003/health 2>/dev/null || echo '{"status":"DOWN"}')
STATUS=$(echo "$HEALTH" | grep -o '"status":"[^"]*"' | grep -o '"[^"]*"$')
UPTIME=$(echo "$HEALTH" | grep -o '"uptime":[0-9]*' | grep -o '[0-9]*')
LLM=$(echo "$HEALTH" | grep -o '"llmMode":"[^"]*"' | grep -o '"[^"]*"$')

EVOS=$(grep -o '"totalEvolutions":[0-9]*' "$DIR/memory_store/evolution_state.json" 2>/dev/null | grep -o '[0-9]*')
MODS=$(ls "$DIR/scripts/generated/evolved_"*.js 2>/dev/null | wc -l)
NEW_MODS=$(ls -lt "$DIR/scripts/generated/evolved_"*.js 2>/dev/null | grep "$(date '+%b %d')" | wc -l)
RECENT=$(grep '"id"\|"dimension"\|"result"\|"score"\|"reverted"' "$DIR/memory_store/evolution.json" 2>/dev/null | tail -20 | tr '\n' '|')

# Last 5 module sizes
SIZES=$(ls -lt "$DIR/scripts/generated/evolved_"*.js 2>/dev/null | head -5 | awk '{print $5}' | tr '\n' ' ')

TLM_FILE="$DIR/monitoring/three_layer_metrics.json"
if [ -f "$TLM_FILE" ]; then
  PHI=$(grep -o '"phi":[0-9.]*' "$TLM_FILE" | tail -1 | grep -o '[0-9.]*')
  PC_ERR=$(grep -o '"globalAvgError":[0-9.]*' "$TLM_FILE" | tail -1 | grep -o '[0-9.]*')
  NEURO_MODE=$(grep -o '"mode":"[^"]*"' "$TLM_FILE" | tail -1 | grep -o '"[^"]*"$')
  SNN_READY=$(grep -o '"ready":[a-z]*' "$TLM_FILE" | tail -1 | grep -o '[a-z]*$')
  PHI_EVO_CORR=$(grep -o '"phiEvolutionCorrelation":[-0-9.]*' "$TLM_FILE" | tail -1 | grep -o '[-0-9.]*')
else
  PHI="N/A"; PC_ERR="N/A"; NEURO_MODE="N/A"; SNN_READY="N/A"; PHI_EVO_CORR="N/A"
fi

echo "[$NOW] status=$STATUS uptime=${UPTIME}s evos=$EVOS mods=$MODS new_today=$NEW_MODS llm=$LLM sizes=[$SIZES]" >> "$LOG"
echo "[$NOW] v10.0-3L: phi=$PHI pc_err=$PC_ERR neuro_mode=$NEURO_MODE snn=$SNN_READY phi_evo_corr=$PHI_EVO_CORR" >> "$LOG"
echo "[$NOW] recent: $RECENT" >> "$LOG"
echo "---" >> "$LOG"

if [ -f "$DIR/monitoring/three_layer_metrics.json" ]; then
  WDT_TRIPS=$(grep -o '"wdt_trip":[0-9]*' "$DIR/monitoring/hourly.log" 2>/dev/null | tail -1 | grep -o '[0-9]*')
  ESTOP_A=$(grep -o '"channelA":[a-z]*' "$DIR/monitoring/hourly.log" 2>/dev/null | tail -1 | grep -o '[a-z]*$')
  ESTOP_B=$(grep -o '"channelB":[a-z]*' "$DIR/monitoring/hourly.log" 2>/dev/null | tail -1 | grep -o '[a-z]*$')
  BATTERY=$(grep -o '"batteryPct":[0-9.]*' "$DIR/monitoring/hourly.log" 2>/dev/null | tail -1 | grep -o '[0-9.]*')
  MAX_TEMP=$(grep -o '"temp":[0-9.]*' "$DIR/monitoring/hourly.log" 2>/dev/null | tail -1 | grep -o '[0-9.]*')
  SAFETY_PORTS=$(grep -o '"safetyPorts":[0-9]*' "$DIR/monitoring/hourly.log" 2>/dev/null | tail -1 | grep -o '[0-9]*')
else
  WDT_TRIPS="N/A"; ESTOP_A="N/A"; ESTOP_B="N/A"; BATTERY="N/A"; MAX_TEMP="N/A"; SAFETY_PORTS="N/A"
fi
echo "[$NOW] v10.1-Halos: wdt_trips=$WDT_TRIPS estop_chA=$ESTOP_A estop_chB=$ESTOP_B battery=$BATTERY max_temp=$MAX_TEMP safety_ports=$SAFETY_PORTS" >> "$LOG"
echo "============================================================================" >> "$LOG"
