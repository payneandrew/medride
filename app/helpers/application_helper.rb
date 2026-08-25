module ApplicationHelper
  STATUS_BADGE_CLASSES = {
    "requested" => "bg-status-requested-soft text-status-requested",
    "claimed" => "bg-status-claimed-soft text-status-claimed",
    "in_progress" => "bg-status-in-progress-soft text-status-in-progress",
    "completed" => "bg-status-completed-soft text-status-completed",
    "cancelled" => "bg-status-cancelled-soft text-status-cancelled"
  }.freeze

  def ride_status_badge(status)
    classes = STATUS_BADGE_CLASSES.fetch(status.to_s, "bg-status-requested-soft text-status-requested")
    tag.span status.to_s.humanize, class: "inline-flex items-center rounded-full px-2.5 py-1 text-xs font-semibold whitespace-nowrap #{classes}"
  end

  def needs_authorization_badge
    tag.span "Needs authorization",
      class: "inline-flex items-center gap-1 rounded-full px-2.5 py-1 text-xs font-semibold whitespace-nowrap bg-warn-soft text-warn"
  end

  def level_of_service_label(level_of_service)
    level_of_service.to_s.humanize
  end

  # rank 1 of 1 still renders (you're the only eligible provider, and
  # you're winning by default) — only nil when the ride has no ranking at
  # all, i.e. this provider somehow isn't among the eligible ones.
  def rank_badge(rank, total)
    return if rank.nil?

    classes = rank == 1 ? "bg-status-completed-soft text-status-completed" : "bg-status-requested-soft text-status-requested"
    tag.span "##{rank} of #{total}", class: "inline-flex items-center rounded-full px-2 py-0.5 text-xs font-semibold whitespace-nowrap #{classes}"
  end

  # Centralized so the whole app's button/input/card look is a one-line
  # change, not a find-and-replace across a dozen .erb files.
  def btn_primary
    "inline-flex items-center justify-center gap-1.5 rounded-lg bg-accent px-4 py-2 text-sm font-medium text-accent-ink shadow-sm hover:bg-accent-strong transition-colors cursor-pointer disabled:opacity-50 disabled:cursor-not-allowed"
  end

  def btn_secondary
    "inline-flex items-center justify-center gap-1.5 rounded-lg border border-line bg-panel px-4 py-2 text-sm font-medium text-ink hover:bg-paper transition-colors cursor-pointer"
  end

  def btn_subtle_danger
    "inline-flex items-center justify-center gap-1.5 rounded-lg border border-line px-3 py-1.5 text-sm font-medium text-muted hover:bg-status-cancelled-soft hover:text-status-cancelled hover:border-status-cancelled/30 transition-colors cursor-pointer"
  end

  def input_classes
    "w-full rounded-lg border border-line bg-panel px-3 py-2 text-sm text-ink placeholder:text-faint focus:border-accent focus:outline-none focus:ring-2 focus:ring-accent/20 transition-shadow"
  end

  def card_classes(extra = nil)
    [ "rounded-xl border border-line bg-panel p-5 shadow-sm", extra ].compact.join(" ")
  end
end
