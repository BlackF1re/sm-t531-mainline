// SPDX-License-Identifier: GPL-2.0-only
#include <linux/module.h>
#include <linux/tracepoint.h>
#include <linux/debugfs.h>
#include <linux/seq_file.h>
#include <linux/workqueue.h>
#include <linux/of.h>
#include <drm/gpu_scheduler.h>
#include "msm_gem.h"
#define LIMIT 16384
struct row { u64 ns, uctx, useq, fctx, fseq, hctx, hseq; u32 id, pid; };
static struct row rows[LIMIT];
static atomic_t used = ATOMIC_INIT(0);
static struct tracepoint *hook;
static struct dentry *root;
static bool stopped;
module_param(stopped, bool, 0400);
static void capture(void *data, struct msm_gem_submit *s, u64 elapsed, u64 clock, u64 start, u64 end)
{
 int i = atomic_fetch_inc(&used); struct row *r;
 if (i >= LIMIT) return;
 r=&rows[i]; r->ns=ktime_get_mono_fast_ns(); r->id=s->ident; r->pid=pid_nr(s->pid);
 if(s->user_fence) {r->uctx=s->user_fence->context;r->useq=s->user_fence->seqno;}
 r->fctx=r->uctx; r->fseq=r->useq;
 if(s->hw_fence) {r->hctx=s->hw_fence->context;r->hseq=s->hw_fence->seqno;}
}
static int notify(struct notifier_block *nb, unsigned long action, void *data)
{
 struct tp_module *tm=data; unsigned int i;
 if(strcmp(tm->mod->name,"msm")) return NOTIFY_DONE;
 if(action==MODULE_STATE_COMING && !stopped) {
  for(i=0;i<tm->mod->num_tracepoints;i++) {
   struct tracepoint *tp=tracepoint_ptr_deref(&tm->mod->tracepoints_ptrs[i]);
   if(!strcmp(tp->name,"msm_gpu_submit_retired")) {
    if(!tracepoint_probe_register(tp,capture,NULL)) hook=tp;
   }
  }
 }
 if(action==MODULE_STATE_GOING && hook) {tracepoint_probe_unregister(hook,capture,NULL);hook=NULL;}
 return NOTIFY_OK;
}
static struct notifier_block nb={.notifier_call=notify};
static void stop(struct work_struct *work)
{
 unregister_tracepoint_module_notifier(&nb);
 tracepoint_synchronize_unregister();
 WRITE_ONCE(stopped,true);
}
static DECLARE_DELAYED_WORK(stop_work,stop);
static int show_show(struct seq_file *m,void *v)
{
 int i,n=atomic_read(&used);
 if(!READ_ONCE(stopped)) return -EBUSY;
 seq_printf(m,"count=%d overflow=%d\n",n,n>LIMIT);
 seq_puts(m,"ns id pid user_ctx user_seq sched_ctx sched_seq hw_ctx hw_seq\n");
 for(i=0;i<min(n,LIMIT);i++) {struct row*r=&rows[i];seq_printf(m,"%llu %u %u %llu %llu %llu %llu %llu %llu\n",r->ns,r->id,r->pid,r->uctx,r->useq,r->fctx,r->fseq,r->hctx,r->hseq);}
 return 0;
}
DEFINE_SHOW_ATTRIBUTE(show);
static int __init start(void)
{
 int ret;
 if(!of_machine_is_compatible("samsung,matisse3g"))return -ENODEV;
 ret=register_tracepoint_module_notifier(&nb);if(ret)return ret;
 if(!hook){unregister_tracepoint_module_notifier(&nb);return -ENODEV;}
 root=debugfs_create_dir("t531_fence_owner",NULL);
 debugfs_create_file("records",0400,root,NULL,&show_fops);
 schedule_delayed_work(&stop_work,30*HZ);
 return 0;
}
static void __exit finish(void)
{
 cancel_delayed_work_sync(&stop_work);
 if(!stopped)stop(NULL);
 debugfs_remove_recursive(root);
}
module_init(start);module_exit(finish);MODULE_LICENSE("GPL");
MODULE_DESCRIPTION("Bounded SM-T531 submit-to-fence ownership capture; no register writes");
