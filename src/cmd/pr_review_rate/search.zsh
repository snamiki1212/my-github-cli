#!/bin/bash

######################################################
##
## Configs
##
######################################################

REPO="SSK-TBD/bluage" # プロジェクトのリポジトリ名（例: openai/chatgpt）
LABEL="cc_backend" # タグBを設定

# 最大数1_000 しか gh が対応できないので、これ以上欲しい場合はページネーション or gh 以外で考える
# 注意: reviewed_byがresponseになくてrequest にしか載せられないため、2回別のargsでAPI投げてる関係から、ここの値が少ないと壊れるまたは1kを超えると壊れるので注意。TODO: そうなったら gh pr list でうまくできないか調べる
LIMIT="1000"

ME="snamiki1212"
SEARCH_FROM="2024-10-01"
SEARCH_TO="2024-11-01"
verbose=true # true だと詳細情報も追加

# TODO
# タイトルにrevert が含まれる時、除外しても良さそう

##########q############################################
##
## Main
##
######################################################
cmd_base="gh search prs --repo $REPO --label $LABEL --created \"$SEARCH_FROM..$SEARCH_TO\" --limit $LIMIT --json number,url --merged"
cmd_all_prs="$cmd_base                   -- -author:app/dependabot -author:$ME"
cmd_my_prs=" $cmd_base --reviewed-by $ME -- -author:app/dependabot -author:$ME"

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
APPROVED_PRs=$(eval $cmd_my_prs) # cmd 実行
APPROVED_PRs=$(echo $APPROVED_PRs | tr -d '[:cntrl:]') # 改行コードを削除: https://qiita.com/re-sasaki/items/7d34109cf209a8ac753c

# echo "<<"
# # echo "APPROVED_PRs: $APPROVED_PRs"
# x=$(echo $APPROVED_PRs | jq .)
# echo $x
# echo "||"

# 総PR数を取得
ALL_COUNT=$(echo "$ALL_PRs" | jq '. | length')
# if [ "$ALL_COUNT" -eq 0 ]; then
#   echo "タグ \"$LABEL\" が付いたPRはありません。"
#   exit 0
# fi

# 件数取得
APPROVED_COUNT=$(echo $APPROVED_PRs | jq '. | length')

# 比率を計算
APPROVAL_RATE=$(echo "scale=2; ($APPROVED_COUNT / $ALL_COUNT) * 100" | bc)

# Output
result=$(jq -n \
  --arg from "$SEARCH_FROM" \
  --arg to "$SEARCH_TO" \
  --arg approved_count "$APPROVED_COUNT" \
  --arg approval_rate "$APPROVAL_RATE" \
  --arg all "$ALL_COUNT" \
  '{
    from: $from,
    to: $to,
    approved_count: $approved_count,
    approval_rate: $approval_rate,
    all: $all
  }')

if [ "$verbose" = true ]; then
  # all PR numbers
  list1=$(echo $ALL_PRs | jq '[.[] | .url]')
  result=$(jq --arg list1 "$list1" '. + {all_prs: $list1}' <<< $result)

  # approved PR numbers
  list2=$(echo $APPROVED_PRs | jq '[.[] | .url]')
  result=$(jq --arg list2 "$list2" '. + {approved_prs: $list2}' <<< $result)

  # not approved PR numbers
  list3=$(echo $ALL_PRs | jq --argjson list2 "$list2" '[.[] | select(.url | IN($list2[]) | not) | .url]')
  result=$(jq --arg list3 "$list3" '. + {not_approved_pr: $list3}' <<< $result)
fi

echo $result