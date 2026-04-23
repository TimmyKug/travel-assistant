import { describe, expect, it, vi, beforeEach } from "vitest";
import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { MemoryRouter, Route, Routes } from "react-router-dom";
import Register from "./Register";
import { AuthProvider } from "../AuthContext";
import * as api from "../services/api";

vi.mock("../services/api", () => ({
  default: {
    post: vi.fn(),
  },
}));

function renderRegister(path = "/register") {
  return render(
    <MemoryRouter initialEntries={[path]} future={{ v7_relativeSplatPath: true, v7_startTransition: true }}>
      <AuthProvider>
        <Routes>
          <Route path="/register" element={<Register />} />
          <Route path="/" element={<p>Dashboard</p>} />
        </Routes>
      </AuthProvider>
    </MemoryRouter>
  );
}

describe("Register", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    localStorage.clear();
  });

  it("renders the registration form", () => {
    renderRegister();

    expect(screen.getByRole("heading", { name: /ai travel assistant/i })).toBeInTheDocument();
    expect(screen.getByPlaceholderText(/your name/i)).toBeInTheDocument();
    expect(screen.getByPlaceholderText(/you@example.com/i)).toBeInTheDocument();
    expect(screen.getByPlaceholderText(/••••••••/i)).toBeInTheDocument();
    expect(screen.getByRole("button", { name: /create account/i })).toBeInTheDocument();
  });

  it("shows a link to the login page", () => {
    renderRegister();

    const link = screen.getByRole("link", { name: /sign in/i });
    expect(link).toBeInTheDocument();
    expect(link).toHaveAttribute("href", "/login");
  });

  it("registers successfully and navigates to dashboard", async () => {
    vi.mocked(api.default.post).mockResolvedValue({
      data: { name: "Tim", user_id: "user-1", token: "test-token" },
    });

    const user = userEvent.setup();
    renderRegister();

    await user.type(screen.getByPlaceholderText(/your name/i), "Tim");
    await user.type(screen.getByPlaceholderText(/you@example.com/i), "tim@example.com");
    await user.type(screen.getByPlaceholderText(/••••••••/i), "password123");
    await user.click(screen.getByRole("button", { name: /create account/i }));

    expect(api.default.post).toHaveBeenCalledWith("/auth/register", {
      name: "Tim",
      email: "tim@example.com",
      password: "password123",
    });
    expect(localStorage.getItem("token")).toBe("test-token");
    expect(JSON.parse(localStorage.getItem("user") ?? "{}")).toEqual({ name: "Tim", user_id: "user-1" });
    expect(await screen.findByText("Dashboard")).toBeInTheDocument();
  });

  it("displays error message on registration failure", async () => {
    vi.mocked(api.default.post).mockRejectedValue({
      response: { data: { detail: "Email already exists" } },
    });

    const user = userEvent.setup();
    renderRegister();

    await user.type(screen.getByPlaceholderText(/your name/i), "Tim");
    await user.type(screen.getByPlaceholderText(/you@example.com/i), "taken@example.com");
    await user.type(screen.getByPlaceholderText(/••••••••/i), "password123");
    await user.click(screen.getByRole("button", { name: /create account/i }));

    expect(await screen.findByText("Email already exists")).toBeInTheDocument();
  });

  it("shows a fallback error message when the server responds without detail", async () => {
    vi.mocked(api.default.post).mockRejectedValue({ response: { data: {} } });

    const user = userEvent.setup();
    renderRegister();

    await user.type(screen.getByPlaceholderText(/your name/i), "Tim");
    await user.type(screen.getByPlaceholderText(/you@example.com/i), "tim@example.com");
    await user.type(screen.getByPlaceholderText(/••••••••/i), "password");
    await user.click(screen.getByRole("button", { name: /create account/i }));

    expect(await screen.findByText("Registration failed")).toBeInTheDocument();
  });

  it("disables the button while loading", async () => {
    vi.mocked(api.default.post).mockImplementation(
      () => new Promise((resolve) => setTimeout(() => resolve({ data: { name: "Tim", user_id: "user-1", token: "token" } }), 100))
    );

    const user = userEvent.setup();
    renderRegister();

    const button = screen.getByRole("button", { name: /create account/i });
    await user.type(screen.getByPlaceholderText(/your name/i), "Tim");
    await user.type(screen.getByPlaceholderText(/you@example.com/i), "tim@example.com");
    await user.type(screen.getByPlaceholderText(/••••••••/i), "password");
    await user.click(button);

    expect(button).toBeDisabled();
    expect(screen.getByRole("button", { name: /creating account/i })).toBeInTheDocument();
  });
});
