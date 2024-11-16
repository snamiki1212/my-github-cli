#!/bin/bash

######################################################
##
## Configs
##
######################################################

REPO="SSK-TBD/bluage" # プロジェクトのリポジトリ名（例: openai/chatgpt）
LABEL="cc_backend" # タグBを設定
LIMIT="30" # 最大数1_000 しか gh が対応できないので、これ以上欲しい場合はページネーション or gh 以外で考える
ME="snamiki1212"
SEARCH_FROM="2024-11-01"
SEARCH_TO="2024-12-01"
verbose=true

######################################################
##
## Main
##
######################################################
cmd="gh search prs --repo $REPO --label $LABEL --reviewed-by $ME --created \"$SEARCH_FROM..$SEARCH_TO\" --limit $LIMIT --json number,labels,reviews"

# log
echo "Runnin following cmd...
> $cmd
"

# PR情報を取得
PR_DATA=$(eval $cmd) # cmd 実行
PR_DATA=$(echo $PR_DATA | tr -d '[:cntrl:]') # 改行コードを削除: https://qiita.com/re-sasaki/items/7d34109cf209a8ac753c

# echo "<<"
# # echo "PR_DATA: $PR_DATA"
# x=$(echo $PR_DATA | jq .)
# echo $x
# echo "||"

# 総PR数を取得
TOTAL=$(echo "$PR_DATA" | jq '. | length')
if [ "$TOTAL" -eq 0 ]; then
  echo "タグ \"$LABEL\" が付いたPRはありません。"
  exit 0
fi

# PR取得
APPROVED_PRs=$(echo "$PR_DATA" | jq --arg ME "$ME" '[.[] | select(.reviews[]?.author.login == $ME)]') # PRへApprove系した数（approve/comment/block）
COMMENTED_PRs=$(echo "$PR_DATA" | jq --arg ME "$ME" '[.[] | select(.comments[]?.author.login == $ME)]') # PRへコメントした数


# echo "APPROVED_PRs: $APPROVED_PRs"
if [ "$verbose" = true ]; then
  debug=$(echo $APPROVED_PRs | jq '[.[] | .number]')
  echo "approved_pr_numbers: $debug"
fi


# 件数取得
APPROVED_COUNT=$(echo $APPROVED_PRs | jq '. | length')
COMMENTED_COUNT=$(echo $COMMENTED_PRs | jq '. | length')

# 比率を計算
APPROVAL_RATE=$(echo "scale=2; ($APPROVED_COUNT / $TOTAL) * 100" | bc)
COMMENT_RATE=$(echo "scale=2; ($COMMENTED_COUNT / $TOTAL) * 100" | bc)

# Output
result=$(jq -n \
  --arg from "$SEARCH_FROM" \
  --arg to "$SEARCH_TO" \
  --arg approved_count "$APPROVED_COUNT" \
  --arg commented_count "$COMMENTED_COUNT" \
  --arg approval_rate "$APPROVAL_RATE" \
  --arg comment_rate "$COMMENT_RATE" \
  --arg total "$TOTAL" \
  '{
    from: $from,
    to: $to,
    approved_count: $approved_count,
    commented_count: $commented_count,
    approval_rate: $approval_rate,
    comment_rate: $comment_rate,
    total: $total
  }')
echo $result