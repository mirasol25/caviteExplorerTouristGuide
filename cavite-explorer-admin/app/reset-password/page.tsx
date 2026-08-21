"use client";

import { FormEvent, useEffect, useState } from "react";

const API = process.env.NEXT_PUBLIC_API_URL ?? "http://localhost:3000";

export default function ResetPasswordPage() {
  const [password, setPassword] = useState("");
  const [confirm, setConfirm] = useState("");
  const [message, setMessage] = useState("");
  const [updated, setUpdated] = useState(false);
  const [isMobile, setIsMobile] = useState(false);
  useEffect(() => setIsMobile(new URLSearchParams(window.location.search).get("client") === "mobile"), []);
  const submit = async (event: FormEvent) => {
    event.preventDefault();
    const token = new URLSearchParams(window.location.search).get("token");
    if (!token) return setMessage("This password-reset link is missing or has expired. Request a new one.");
    if (password.length < 8) return setMessage("Use at least 8 characters.");
    if (password !== confirm) return setMessage("Passwords do not match.");
    const response = await fetch(`${API}/auth/reset-password`, { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ token, newPassword: password }) });
    const data = await response.json().catch(() => ({}));
    setUpdated(response.ok);
    setMessage(response.ok ? "Password updated successfully." : (data.message ?? "Could not update password."));
  };
  return <main className="login"><section><p className="eyebrow">CAVITE EXPLORER</p><h1>Set a new password</h1><p>Choose a strong password you have not used elsewhere.</p>{!updated && <form onSubmit={submit}><input type="password" placeholder="New password" value={password} onChange={(e) => setPassword(e.target.value)} required /><input type="password" placeholder="Confirm new password" value={confirm} onChange={(e) => setConfirm(e.target.value)} required /><button>Update password</button></form>}{message && <b className={updated ? "form-message success-message" : "error"}>{message}</b>}{updated && <a className="primary reset-return-link" href={isMobile ? "caviteexplorer://login-callback?passwordReset=success" : "/"}>{isMobile ? "Open Cavite Explorer" : "Return to sign in"}</a>}</section></main>;
}
