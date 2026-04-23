import { afterEach, describe, expect, it, vi } from "vitest";
import { downloadTripMarkdown, formatTripMarkdown, formatTripPlanMarkdown } from "./tripMarkdown";

afterEach(() => {
  vi.restoreAllMocks();
});

describe("tripMarkdown utils", () => {
  it("formats a structured plan into markdown with itinerary/hotels/budget sections", () => {
    const markdown = formatTripPlanMarkdown({
      trip_title: "Central Europe Sprint",
      destination: "Vienna",
      summary: "4-day fast-paced route.",
      days: [
        {
          day: 1,
          date: "2026-05-01",
          items: [
            {
              time: "09:00",
              title: "Museum Quarter",
              description: "Start with modern art.",
              category: "activity",
              estimated_cost: "15 EUR",
            },
          ],
        },
      ],
      hotels: [
        {
          night: 1,
          options: [
            {
              name: "Boutique Inn",
              area: "Innere Stadt",
              nightly_estimate: "140 EUR",
              reason: "Walkable old town location",
            },
          ],
        },
      ],
      budget: {
        currency: "EUR",
        estimated_total: "550",
        notes: "Includes train transfers.",
      },
    });

    expect(markdown).toContain("# Central Europe Sprint");
    expect(markdown).toContain("## Itinerary");
    expect(markdown).toContain("### Day 1 (2026-05-01)");
    expect(markdown).toContain("Museum Quarter");
    expect(markdown).toContain("## Hotel Suggestions By Night");
    expect(markdown).toContain("## Budget");
  });

  it("formats an unstructured trip into markdown with dates and notes", () => {
    const markdown = formatTripMarkdown({
      id: "trip-plain",
      title: "Plain Trip",
      destination: "Prague",
      start_date: "2026-06-01",
      end_date: "2026-06-03",
      notes: "Bring comfortable walking shoes.",
    });

    expect(markdown).toContain("# Plain Trip");
    expect(markdown).toContain("**Destination:** Prague");
    expect(markdown).toContain("**Dates:** 2026-06-01 - 2026-06-03");
    expect(markdown).toContain("## Notes");
    expect(markdown).toContain("Bring comfortable walking shoes.");
  });

  it("downloads markdown with a sanitized filename", () => {
    const createObjectURL = vi.spyOn(URL, "createObjectURL").mockReturnValue("blob:test-url");
    const revokeObjectURL = vi.spyOn(URL, "revokeObjectURL").mockImplementation(() => {});
    const appendChild = vi.spyOn(document.body, "appendChild");

    const originalCreateElement = document.createElement.bind(document);
    const anchor = originalCreateElement("a");
    const clickSpy = vi.spyOn(anchor, "click").mockImplementation(() => {});
    vi.spyOn(anchor, "remove").mockImplementation(() => {});
    vi.spyOn(document, "createElement").mockImplementation((tagName: string) => {
      if (tagName.toLowerCase() === "a") return anchor;
      return originalCreateElement(tagName);
    });

    downloadTripMarkdown("# markdown", "My Trip!!! Summer 2026");

    expect(createObjectURL).toHaveBeenCalled();
    expect(appendChild).toHaveBeenCalledWith(anchor);
    expect(anchor.href).toBe("blob:test-url");
    expect(anchor.download).toBe("my-trip-summer-2026.md");
    expect(clickSpy).toHaveBeenCalled();
    expect(revokeObjectURL).toHaveBeenCalledWith("blob:test-url");
  });
});
