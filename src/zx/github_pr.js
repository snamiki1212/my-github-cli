#!/usr/bin/env zx

// ===== 設定 =====
const REPO = "SSK-TBD/bluage"; // org/repo
const USERNAME = "snamiki1212"; // 自分の GitHub ユーザー名
const START_DATE = "2025-05-08";
const END_DATE = "2025-05-15";
// ================

$.verbose = false;

const listPrs = async () => {
  // 期間内の PR を取得
  const prsRaw =
    await $`gh pr list --repo ${REPO} --state merged --limit 1000 --search "-author:yoshi-jr merged:${START_DATE}..${END_DATE}" --json number,title,url`;
  const prs = JSON.parse(prsRaw.stdout);
  return prs;
};

const getPrDetails = async (prNumber) => {
  // PR の詳細を取得
  const query = `
  query {
    repository(owner: "${REPO.split("/")[0]}", name: "${REPO.split("/")[1]}") {
      pullRequest(number: ${prNumber}) {
        reviews(first: 100) {
          nodes {
            author { login }
            state
          }
        }
        reviewThreads(first: 100) {
          nodes {
            isResolved
            comments(first: 20) {
              nodes {
                author { login }
                body
              }
            }
          }
        }
      }
    }
  }`;

  const response = await $`gh api graphql -f query=${query}`;
  return JSON.parse(response.stdout).data.repository.pullRequest;
};

const analysisPr = async (pr) => {
  /// 自分がレビュー（Approve) したかどうか
  const reviews = pr.reviews.nodes;
  const isApproved = reviews.some(
    (r) => r.author?.login === USERNAME && r.state === "APPROVED"
  );

  // 自分がコメントしたかどうか
  const threads = pr.reviewThreads.nodes;
  const isCommented = threads.some((thread) => {
    const comments = thread.comments.nodes;
    return comments.some((c) => c.author?.login === USERNAME);
  });

  // コメントした内容の一覧
  const comments = [];
  for (const thread of threads) {
    const threadComments = thread.comments.nodes;
    for (const comment of threadComments) {
      if (comment.author?.login === USERNAME) {
        comments.push(comment.body);
      }
    }
  }

  return { isApproved, isCommented, comments };
};

const main = async () => {
  // PR のリストを取得
  const prs = await listPrs();

  console.log(`期間内の PR 数: ${prs.length}`);

  // PR の詳細を取得
  const prDetails = [];
  for (const pr of prs) {
    const { number, title, url } = pr;
    const prData = await getPrDetails(number);
    if (!prData) {
      console.log(`PR ${number} のデータが取得できませんでした。`);
      continue;
    }
    prDetails.push({ number, title, url, ...prData });
  }

  console.log("PRの詳細を取得しました。");

  // PR を分析
  const analysisResults = [];
  for (const pr of prDetails) {
    const { number, title, url } = pr;
    const { isApproved, isCommented, comments } = await analysisPr(pr);
    analysisResults.push({
      number,
      title,
      url,
      isApproved,
      isCommented,
      comments,
    });
  }

  console.log("PRの分析が完了しました。");

  // 結果を表示
  const totalPrs = analysisResults.length;
  const approvedPrs = analysisResults.filter((pr) => pr.isApproved).length;
  const commentedPrs = analysisResults.filter((pr) => pr.isCommented).length;

  // Markdown出力
  let markdown = "";
  markdown += `# レビュー集計レポート\n\n`;
  markdown += `- 対象期間: ${START_DATE} ～ ${END_DATE}\n`;
  markdown += `- 対象リポジトリ: ${REPO}\n`;
  markdown += `- 合計PR数: ${totalPrs}\n`;
  markdown += `- 承認したPR数: ${approvedPrs}\n`;
  markdown += `- コメントしたPR数: ${commentedPrs}\n\n`;
  markdown += "---\n\n";
  markdown += "## ✅ 承認したPR一覧\n\n";

  for (const pr of analysisResults) {
    if (pr.isApproved) {
      markdown += `### [#${pr.number} ${pr.title}](${pr.url})\n\n`;
      if (pr.isCommented) {
        markdown += `- コメントあり\n`;
        for (const comment of pr.comments) {
          markdown += `  - ${comment.replace(/\n/g, " ")}\n`;
        }
      } else {
        markdown += `- コメントなし\n`;
      }
      markdown += `\n---\n\n`;
    }
  }

  const fileName = `./review-summary/reports/${START_DATE.replace(
    /-/g,
    ""
  )}_${END_DATE.replace(/-/g, "")}.md`;
  await fs.writeFile(fileName, markdown);
  console.log("Markdown レポートを出力しました:", fileName);
};

main();
