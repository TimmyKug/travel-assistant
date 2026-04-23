import { describe, expect, it, vi, beforeEach } from "vitest";
import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { MemoryRouter, Route, Routes } from "react-router-dom";
import Login from "./Login";
import { AuthProvider } from "../AuthContext";
import * as api from "../services/api";

vi.mock("../services/api", () => ({
  default: {
    post: vi.fn(),
  },
}));

function renderLogin(path = "/login") {
  return render(
    <MemoryRouter initialEntries={[path]} future={{ v7_relativeSplatPath: true, v7_startTransition: true }}>
      <AuthProvider>
        <Routes>
          <Route path="/login" element={<Login />} />
          <Route path="/" element={<p>Dashboard</p>} />
        </Routes>
      </AuthProvider>
    </MemoryRouter>
  );
}

describe("Login", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    localStorage.clear();
  });

  it("renders the login form", () => {
    renderLogin();

    expect(screen.getByRole("heading", { name: /ai travel assistant/i })).toBeInTheDocument();
    expect(screen.getByPlaceholderText(/you@example.com/i)).toBeInTheDocument();
    expect(screen.getByPlaceholderText(/••••••••/i)).toBeInTheDocument();
    expect(screen.getByRole("button", { name: /sign in/i })).toBeInTheDocument();
  });

  it("shows a link to the registration page", () => {
    renderLogin();

    const link = screen.getByRole("link", { name: /create one/i });
    expect(link).toBeInTheDocument();
    expect(link).toHaveAttribute("href", "/register");
  });

  it("logs in successfully and navigates to dashboard", async () => {
    vi.mocked(api.default.post).mockResolvedValue({
      data: { name: "Tim", user_id: "user-1", token: "test-token" },
    });

    const user = userEvent.setup();
    renderLogin();

    await user.type(screen.getByPlaceholderText(/you@example.com/i), "tim@example.com");
    await user.type(screen.getByPlaceholderText(/••••••••/i), "password123");
    await user.click(screen.getByRole("button", { name: /sign in/i }));

    expect(api.default.post).toHaveBeenCalledWith("/auth/login", {
      email: "tim@example.com",
      password: "password123",
    });
    expect(localStorage.getItem("token")).toBe("test-token");
    expect(JSON.parse(localStorage.getItem("user") ?? "{}")).toEqual({ name: "Tim", user_id: "user-1" });
    expect(await screen.findByText("Dashboard")).toBeInTheDocument();
  });

  it("displays error message on login failure", async () => {
    vi.mocked(api.default.post).mockRejectedValue({
      response: { data: { detail: "Invalid credentials" } },
    });

    const user = userEvent.setup();
    renderLogin();

    await user.type(screen.getByPlaceholderText(/you@example.com/i), "tim@example.com");
    await user.type(screen.getByPlaceholderText(/••••••••/i), "wrongpassword");
    await user.click(screen.getByRole("button", { name: /sign in/i }));

    expect(await screen.findByText("Invalid credentials")).toBeInTheDocument();
  });

  it("shows a fallback error message when the server responds without detail", async () => {
    vi.mocked(api.default.post).mockRejectedValue({ response: { data: {} } });

    const user = userEvent.setup();
    renderLogin();

    await user.type(screen.getByPlaceholderText(/you@example.com/i), "tim@example.com");
    await user.type(screen.getByPlaceholderText(/••••••••/i), "password");
    await user.click(screen.getByRole("button", { name: /sign in/i }));

    expect(await screen.findByText("Login failed")).toBeInTheDocument();
  });

  it("disables the button while loading", async () => {
    vi.mocked(api.default.post).mockImplementation(
      () => new Promise((resolve) => setTimeout(() => resolve({ data: { name: "Tim", user_id: "user-1", token: "token" } }), 100))
    );

    const user = userEvent.setup();
    renderLogin();

    const button = screen.getByRole("button", { name: /sign in/i });
    await user.type(screen.getByPlaceholderText(/you@example.com/i), "tim@example.com");
    await user.type(screen.getByPlaceholderText(/••••••••/i), "password");
    await user.click(button);

    expect(button).toBeDisabled();
    expect(screen.getByRole("button", { name: /signing in/i })).toBeInTheDocument();
  });

  it("clears previous errors when trying again", async () => {
    renderLogin();
    vi.mocked(api.default.post).mockRejectedValueOnce({ response: { data: { detail: "First error" } } });

    const user = userEvent.setup();
    const emailInput = screen.getByPlaceholderText(/you@example.com/i);
    const passwordInput = screen.getByPlaceholderText(/••••••••/i);

    await user.type(emailInput, "tim@example.com");
    await user.type(passwordInput, "password");
    await user.click(screen.getByRole("button", { name: /sign in/i }));

    expect(await screen.findByText("First error")).toBeInTheDocument();

    vi.mocked(api.default.post).mockResolvedValueOnce({
      data: { name: "Tim", user_id: "user-1", token: "token" },
    });

    await user.clear(emailInput);
    await user.clear(passwordInput);
    await user.type(emailInput, "tim@example.com");
    await user.type(passwordInput, "password");
    await user.click(screen.getByRole("button", { name: /sign in/i }));

    expect(screen.queryByText("First error")).not.toBeInTheDocument();
  });
});
