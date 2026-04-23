import { describe, expect, it, beforeEach, vi } from "vitest";
import MockAdapter from "axios-mock-adapter";
import api from "./api";

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
