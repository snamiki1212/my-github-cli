#!/bin/bash

######################################################
##
## Configs
##
######################################################

REPO="SSK-TBD/bluage" # プロジェクトのリポジトリ名（例: openai/chatgpt）
LABEL="cc_backend" # タグBを設定
LIMIT="1000" # 最大数1_000 しか gh が対応できないので、これ以上欲しい場合はページネーション or gh 以外で考える
ME="snamiki1212"
SEARCH_FROM="2024-09-01"
SEARCH_TO="2024-10-01"
verbose=true

##########q############################################
##
## Main
##
######################################################
cmd_all_prs="gh search prs --repo $REPO --label $LABEL --created \"$SEARCH_FROM..$SEARCH_TO\" --limit $LIMIT --json number"
cmd_my_prs="$cmd_all_prs --reviewed-by $ME"

# log
echo "Running cmd_all_prs on following...
> $cmd_all_prs
"

# PRs 取得
ALL_PRs=$(eval $cmd_all_prs) # cmd 実行
ALL_PRs=$(echo $ALL_PRs | tr -d '[:cntrl:]') # 改行コードを削除: https://qiita.com/re-sasaki/items/7d34109cf209a8ac753c

# log
echo "Running cmd_my_prs on following...
> $cmd_my_prs
"

# PRs 取得
MY_PRs=$(eval $cmd_my_prs) # cmd 実行
MY_PRs=$(echo $MY_PRs | tr -d '[:cntrl:]') # 改行コードを削除: https://qiita.com/re-sasaki/items/7d34109cf209a8ac753c

# echo "<<"
# # echo "MY_PRs: $MY_PRs"
# x=$(echo $MY_PRs | jq .)
# echo $x
# echo "||"

# 総PR数を取得
ALL=$(echo "$ALL_PRs" | jq '. | length')
if [ "$ALL" -eq 0 ]; then
  echo "タグ \"$LABEL\" が付いたPRはありません。"
  exit 0
fi



# 件数取得
APPROVED_COUNT=$(echo $MY_PRs | jq '. | length')

# 比率を計算
APPROVAL_RATE=$(echo "scale=2; ($APPROVED_COUNT / $ALL) * 100" | bc)

# Output
result=$(jq -n \
  --arg from "$SEARCH_FROM" \
  --arg to "$SEARCH_TO" \
  --arg approved_count "$APPROVED_COUNT" \
  --arg approval_rate "$APPROVAL_RATE" \
  --arg all "$ALL" \
  '{
    from: $from,
    to: $to,
    approved_count: $approved_count,
    approval_rate: $approval_rate,
    all: $all
  }')

if [ "$verbose" = true ]; then
  # all PR numbers
  list1=$(echo $ALL_PRs | jq '[.[] | .number]')
  result=$(jq --arg list1 "$list1" '. + {all_pr_numbers: $list1}' <<< $result)


  # approved PR numbers
  list2=$(echo $MY_PRs | jq '[.[] | .number]')
  result=$(jq --arg list2 "$list2" '. + {approved_pr_numbers: $list2}' <<< $result)

  # not approved PR numbers
  list3=$(echo $ALL_PRs | jq --argjson list2 "$list2" '[.[] | select(.number | IN($list2) | not) | .number]')
  result=$(jq --arg list3 "$list3" '. + {not_approved_pr_numbers: $list3}' <<< $result)
fi

echo $result