import { describe, expect, it, beforeEach, vi } from "vitest";
import MockAdapter from "axios-mock-adapter";
import api from "./api";
import {
  createTrip,
  deleteConversation,
  deleteTrip,
  getConversation,
  getTrip,
  listConversations,
  listTrips,
  renameConversation,
  sendMessage,
  updateTrip,
} from "./api";

const mock = new MockAdapter(api);

describe("api interceptors", () => {
  beforeEach(() => {
    mock.reset();
    localStorage.clear();
  });

  it("uses /api as the base URL", () => {
    expect(api.defaults.baseURL).toBe("/api");
  });

  it("attaches a Bearer token from localStorage on outgoing requests", async () => {
    localStorage.setItem("token", "abc123");
    mock.onGet("/trips/").reply((config) => {
      expect(config.headers?.Authorization).toBe("Bearer abc123");
      return [200, []];
    });

    await api.get("/trips/");
  });

  it("omits the Authorization header when no token is stored", async () => {
    mock.onGet("/trips/").reply((config) => {
      expect(config.headers?.Authorization).toBeUndefined();
      return [200, []];
    });

    await api.get("/trips/");
  });

  it("clears auth storage and redirects to /login on 401 responses", async () => {
    localStorage.setItem("token", "stale");
    localStorage.setItem("user", JSON.stringify({ name: "Tim", user_id: "u1" }));

    const assign = vi.fn();
    Object.defineProperty(window, "location", {
      configurable: true,
      value: { href: "", assign },
    });
    const consoleError = vi.spyOn(console, "error").mockImplementation(() => {});

    mock.onGet("/trips/").reply(401, { detail: "expired" });

    await expect(api.get("/trips/")).rejects.toMatchObject({
      response: { status: 401 },
    });

    expect(localStorage.getItem("token")).toBeNull();
    expect(localStorage.getItem("user")).toBeNull();
    expect(window.location.href).toBe("/login");

    consoleError.mockRestore();
  });

  it("leaves auth storage intact on non-401 errors but still logs them", async () => {
    localStorage.setItem("token", "valid");
    const consoleError = vi.spyOn(console, "error").mockImplementation(() => {});

    mock.onGet("/trips/").reply(500, { detail: "boom" });

    await expect(api.get("/trips/")).rejects.toMatchObject({
      response: { status: 500 },
    });

    expect(localStorage.getItem("token")).toBe("valid");
    expect(consoleError).toHaveBeenCalledWith(
      "API error",
      expect.objectContaining({ status: 500, data: { detail: "boom" } })
    );

    consoleError.mockRestore();
  });
});

describe("api helper functions", () => {
  beforeEach(() => {
    mock.reset();
    localStorage.clear();
  });

  it("sendMessage posts the expected payload and returns response data", async () => {
    mock.onPost("/ai/chat").reply((config) => {
      expect(JSON.parse(config.data)).toEqual({
        content: "Plan Porto",
        conversation_id: "conv-1",
        response_format: "trip_json",
        is_bootstrap: true,
      });
      return [
        200,
        {
          conversation_id: "conv-1",
          assistant_message: "ok",
          recommendations: ["Next step"],
        },
      ];
    });

    const result = await sendMessage("Plan Porto", "conv-1", "trip_json", true);
    expect(result).toEqual({
      conversation_id: "conv-1",
      assistant_message: "ok",
      recommendations: ["Next step"],
    });
  });

  it("conversation helpers call the expected endpoints", async () => {
    mock.onGet("/ai/conversations").reply(200, [{ id: "c1", title: "Trip" }]);
    mock.onGet("/ai/conversations/c1").reply(200, { id: "c1", messages: [] });
    mock.onPatch("/ai/conversations/c1").reply((config) => {
      expect(JSON.parse(config.data)).toEqual({ title: "Renamed" });
      return [200, { id: "c1", title: "Renamed" }];
    });
    mock.onDelete("/ai/conversations/c1").reply(204);

    await expect(listConversations()).resolves.toEqual([{ id: "c1", title: "Trip" }]);
    await expect(getConversation("c1")).resolves.toEqual({ id: "c1", messages: [] });
    await expect(renameConversation("c1", "Renamed")).resolves.toEqual({ id: "c1", title: "Renamed" });
    await expect(deleteConversation("c1")).resolves.toMatchObject({ status: 204 });
  });

  it("trip helpers call the expected endpoints", async () => {
    const trip = { id: "t1", title: "Rome", destination: "Rome" };
    const payload = { title: "Rome", destination: "Rome" };

    mock.onGet("/trips/").reply(200, [trip]);
    mock.onGet("/trips/t1").reply(200, trip);
    mock.onPost("/trips/").reply((config) => {
      expect(JSON.parse(config.data)).toEqual(payload);
      return [200, trip];
    });
    mock.onPut("/trips/t1").reply((config) => {
      expect(JSON.parse(config.data)).toEqual(payload);
      return [200, trip];
    });
    mock.onDelete("/trips/t1").reply(204);

    await expect(listTrips()).resolves.toEqual([trip]);
    await expect(getTrip("t1")).resolves.toEqual(trip);
    await expect(createTrip(payload)).resolves.toEqual(trip);
    await expect(updateTrip("t1", payload)).resolves.toEqual(trip);
    await expect(deleteTrip("t1")).resolves.toMatchObject({ status: 204 });
  });
});
