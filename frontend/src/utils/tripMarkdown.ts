import type { Trip, TripPlan } from "../types";

function cleanFileName(value: string): string {
  return value
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "")
    .slice(0, 80);
}

function parseTripPlanFromTrip(trip: Trip): TripPlan | null {
  if (Array.isArray(trip.itinerary) && trip.itinerary.length > 0) {
    const first = trip.itinerary[0];
    if (
      first &&
      typeof first === "object" &&
      "trip_title" in first &&
      "destination" in first &&
      "days" in first
    ) {
      return first as unknown as TripPlan;
    }
  }
  return null;
}

function getHotelsByNight(plan: TripPlan): Array<{
  night: number;
  date?: string;
  options: Array<{ name: string; area?: string; nightly_estimate?: string; reason?: string }>;
}> {
  if (!Array.isArray(plan.hotels) || plan.hotels.length === 0) return [];
  const first = plan.hotels[0] as unknown;
  if (first && typeof first === "object" && "options" in (first as Record<string, unknown>)) {
    return (plan.hotels as Array<{
      night: number;
      date?: string;
      options: Array<{ name: string; area?: string; nightly_estimate?: string; reason?: string }>;
    }>).filter((entry) => Number.isFinite(entry.night) && Array.isArray(entry.options));
  }
  return [
    {
      night: 1,
      options: (plan.hotels as Array<{ name: string; area?: string; nightly_estimate?: string; reason?: string }>),
    },
  ];
}

export function formatTripPlanMarkdown(plan: TripPlan): string {
  const lines: string[] = [];
  lines.push(`# ${plan.trip_title}`);
  lines.push("");
  lines.push(`**Destination:** ${plan.destination}`);
  if (plan.summary) {
    lines.push("");
    lines.push(plan.summary);
  }

  if (plan.days.length > 0) {
    lines.push("");
    lines.push("## Itinerary");
    for (const day of plan.days) {
      lines.push("");
      lines.push(`### Day ${day.day}${day.date ? ` (${day.date})` : ""}`);
      for (const item of day.items) {
        lines.push(`- ${item.time} — **${item.title}** (${item.category})`);
        lines.push(`  - ${item.description}`);
        if (item.estimated_cost) lines.push(`  - Estimated cost: ${item.estimated_cost}`);
      }
    }
  }

  const hotelsByNight = getHotelsByNight(plan);
  if (hotelsByNight.length) {
    lines.push("");
    lines.push("## Hotel Suggestions By Night");
    for (const night of hotelsByNight) {
      lines.push("");
      lines.push(`### Night ${night.night}${night.date ? ` (${night.date})` : ""}`);
      for (const hotel of night.options) {
        const area = hotel.area ? ` (${hotel.area})` : "";
        const price = hotel.nightly_estimate ? ` — ${hotel.nightly_estimate}/night` : "";
        lines.push(`- **${hotel.name}**${area}${price}`);
        if (hotel.reason) lines.push(`  - ${hotel.reason}`);
      }
    }
  }

  if (plan.budget) {
    lines.push("");
    lines.push("## Budget");
    lines.push(`- Currency: ${plan.budget.currency ?? "n/a"}`);
    lines.push(`- Estimated total: ${plan.budget.estimated_total ?? "n/a"}`);
    if (plan.budget.notes) lines.push(`- Notes: ${plan.budget.notes}`);
  }

  return lines.join("\n").trim();
}

export function formatTripMarkdown(trip: Trip): string {
  const structured = parseTripPlanFromTrip(trip);
  if (structured) return formatTripPlanMarkdown(structured);

  const lines: string[] = [];
  lines.push(`# ${trip.title}`);
  lines.push("");
  lines.push(`**Destination:** ${trip.destination || "n/a"}`);
  if (trip.start_date || trip.end_date) {
    lines.push(`**Dates:** ${trip.start_date ?? "?"} - ${trip.end_date ?? "?"}`);
  }
  if (trip.notes) {
    lines.push("");
    lines.push("## Notes");
    lines.push(trip.notes);
  }
  return lines.join("\n").trim();
}

export function downloadTripMarkdown(markdown: string, title: string): void {
  const fileBase = cleanFileName(title || "trip-itinerary") || "trip-itinerary";
  const blob = new Blob([markdown], { type: "text/markdown;charset=utf-8" });
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = `${fileBase}.md`;
  document.body.appendChild(a);
  a.click();
  a.remove();
  URL.revokeObjectURL(url);
}
