// The native summary already owns task state; add only details it may omit.
export default {
  id: "dots.continuity",
  async setup(ctx) {
    await ctx.session.hook("compaction", (event) => {
      event.system.push({
        type: "text",
        text: "Within the existing summary headings, preserve active user corrections and scope constraints; actions already authorized and approvals still missing; worker session IDs, assigned files, completion/failure state and outstanding results; exact verification commands and passed/failed/not-run outcomes; relevant project memory names and stale facts to recheck; and the next concrete action. Distinguish observed results from intentions. Never turn pending work into completed work. Omit credentials and raw transcripts. Do not change the native summary format.",
      });
    });
  },
};
