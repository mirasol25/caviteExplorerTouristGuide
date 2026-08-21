"use client";

import { ChangeEvent, FormEvent, useEffect, useRef, useState } from "react";

const API = process.env.NEXT_PUBLIC_API_URL ?? "http://localhost:3000";
type Tab = "overview" | "users" | "places" | "transport" | "partners" | "offers";
const tabs: { id: Tab; label: string; icon: string }[] = [
  { id: "overview", label: "Overview", icon: "◫" }, { id: "users", label: "Accounts", icon: "◎" }, { id: "places", label: "Landmarks", icon: "⌖" }, { id: "transport", label: "Transport", icon: "↝" }, { id: "partners", label: "Partners", icon: "♧" }, { id: "offers", label: "Rewards", icon: "✦" },
];

function renderSidebarUser(user: { name?: string; email?: string; role?: string }) {
  const card = document.querySelector(".sidebar-tip");
  if (!card) return;
  const name = user.name || "Portal member";
  const email = user.email || "";
  const role = user.role || "user";
  const details = document.createElement("div");
  details.className = "sidebar-user-details";
  const label = document.createElement("small");
  label.textContent = "SIGNED IN AS";
  const title = document.createElement("strong");
  title.textContent = name;
  const address = document.createElement("span");
  address.textContent = email;
  const badge = document.createElement("em");
  badge.textContent = role;
  details.append(label, title, address, badge);
  const signOut = document.querySelector(".sign-out");
  card.classList.add("user-card");
  card.replaceChildren(details);
  if (signOut) card.append(signOut);
  const workspaceLabel = document.querySelector(".brand span");
  if (workspaceLabel) workspaceLabel.textContent = `${role.toUpperCase()} WORKSPACE`;
}

export default function Home() {
  const [token, setToken] = useState(""); const [tab, setTab] = useState<Tab>("overview"); const [email, setEmail] = useState(""); const [password, setPassword] = useState(""); const [showLoginPassword, setShowLoginPassword] = useState(false); const [forgot, setForgot] = useState(false); const [message, setMessage] = useState("");
  const [data, setData] = useState<Record<string, any[]>>({ users: [], places: [], stops: [], routes: [], tricycleTerminals: [], businesses: [], offers: [] });
  const api = async (path: string, opts: RequestInit = {}) => { const response = await fetch(API + path, { ...opts, headers: { "Content-Type": "application/json", Authorization: `Bearer ${token}`, ...opts.headers } }); const body = await response.json().catch(() => ({})); if (!response.ok) { if (String(body.message || "").toLowerCase().includes("disabled")) { sessionStorage.removeItem("admin_token"); sessionStorage.removeItem("admin_role"); sessionStorage.removeItem("admin_user_id"); setToken(""); } throw Error(body.message || "Request failed"); } return body; };
  const load = async () => { if (!token) return; try { const profile = await api("/auth/me"); const role = profile.user?.role || "user"; sessionStorage.setItem("admin_role", role); sessionStorage.setItem("admin_user_id", profile.user?.id || ""); sessionStorage.setItem("admin_name", profile.user?.name || ""); sessionStorage.setItem("admin_email", profile.user?.email || ""); renderSidebarUser(profile.user || {}); const [users, places, stops, routes, tricycleTerminals, businesses, offers] = await Promise.all([role === "admin" ? api("/admin/users") : Promise.resolve([]), api("/admin/places"), api("/admin/transport/stops"), api("/admin/transport/routes"), api("/admin/transport/tricycle-terminals"), api("/admin/businesses"), api("/admin/offers")]); setData({ users, places, stops, routes, tricycleTerminals, businesses, offers }); setMessage(""); } catch (error: any) { setMessage(error.message); } };
  useEffect(() => { setToken(sessionStorage.getItem("admin_token") || ""); }, []);
  useEffect(() => { const clearSavedSession = (event: MouseEvent) => { const button = (event.target as HTMLElement).closest("button"); if (button?.textContent?.includes("Sign out")) { sessionStorage.removeItem("admin_token"); sessionStorage.removeItem("admin_role"); sessionStorage.removeItem("admin_user_id"); sessionStorage.removeItem("admin_name"); sessionStorage.removeItem("admin_email"); } }; document.addEventListener("click", clearSavedSession); return () => document.removeEventListener("click", clearSavedSession); }, []);
  useEffect(() => { load(); }, [token]);
  useEffect(() => { if (sessionStorage.getItem("admin_role") !== "editor") return; const accounts = Array.from(document.querySelectorAll("nav button")).find((button) => button.textContent?.includes("Accounts")); if (accounts) (accounts as HTMLElement).style.display = "none"; }, [token]);
  const login = async (event: FormEvent) => { event.preventDefault(); setMessage(""); try { const response = await fetch(API + "/auth/login", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ email, password }) }); const body = await response.json(); if (!response.ok) throw Error(body.message || "Login failed"); const profile = await fetch(API + "/auth/me", { headers: { Authorization: `Bearer ${body.token}` } }).then((result) => result.json()); if (!['admin', 'editor'].includes(profile.user?.role)) throw Error("This account does not have portal access."); sessionStorage.setItem("admin_token", body.token); sessionStorage.setItem("admin_role", profile.user.role); setToken(body.token); } catch (error: any) { setMessage(error.message); } };
  const requestReset = async (event: FormEvent) => { event.preventDefault(); setMessage(""); try { const response = await fetch(API + "/auth/forgot-password", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ email, client: "web" }) }); const body = await response.json(); if (!response.ok) throw Error(body.message || "Could not send reset email"); setMessage("Password reset link sent. Check your email to continue."); setForgot(false); } catch (error: any) { setMessage(error.message); } };
  const save = (path: string) => async (event: FormEvent<HTMLFormElement>) => { event.preventDefault(); const form = event.currentTarget; const values: Record<string, any> = Object.fromEntries(new FormData(form)); if (path === "/admin/places") values.images = JSON.parse(values.images || "[]"); try { await api(path, { method: "POST", body: JSON.stringify(values) }); form.reset(); if (path === "/admin/places") { window.dispatchEvent(new Event("landmark-form-reset")); const browse = document.querySelector<HTMLInputElement>("#landmark-view-browse"); if (browse) browse.checked = true; } setMessage("Saved successfully."); load(); } catch (error: any) { setMessage(error.message); } };
  const count = (key: string) => data[key]?.length || 0;
  if (!token) return <main className="login-page"><div className="login-art"><p className="brand-kicker">CAVITE EXPLORER</p><h1>Better journeys begin with trusted local data.</h1><p>One place to keep destinations, commute guidance, community partners, and explorer rewards accurate.</p><div className="login-points"><span>Verified places</span><span>Local transport</span><span>Badge rewards</span></div></div><section className="login-card"><div className="login-mark">CE</div><p className="eyebrow">SECURE WORKSPACE</p><h2>{forgot ? "Reset your password" : "Welcome back"}</h2><p className="login-copy">{forgot ? "Enter your email and we’ll send a secure reset link." : "Sign in to manage the Cavite Explorer experience."}</p><form onSubmit={forgot ? requestReset : login}><label>Email<input aria-label="Email" placeholder="you@example.com" type="email" value={email} onChange={(event) => setEmail(event.target.value)} required /></label>{!forgot && <label>Password<div className="login-password-field"><input aria-label="Password" placeholder="Your password" type={showLoginPassword ? "text" : "password"} value={password} onChange={(event) => setPassword(event.target.value)} required /><button type="button" aria-label={showLoginPassword ? "Hide password" : "Show password"} onClick={() => setShowLoginPassword(!showLoginPassword)}>{showLoginPassword ? "Hide" : "Show"}</button></div></label>}<button className="primary wide">{forgot ? "Send reset link" : "Sign in to portal →"}</button></form><button className="link-button" onClick={() => { setForgot(!forgot); setMessage(""); }}>{forgot ? "← Back to sign in" : "Forgot password?"}</button>{message && <p className="form-message">{message}</p>}</section></main>;
  const activeTab = tabs.find((item) => item.id === tab)!;
  return <main className="app-shell"><aside className="sidebar"><div className="brand"><div className="brand-mark">CE</div><div><strong>Cavite Explorer</strong><span>ADMIN WORKSPACE</span></div></div><nav aria-label="Portal navigation">{tabs.map((item) => <button className={tab === item.id ? "nav-item active" : "nav-item"} onClick={() => setTab(item.id)} key={item.id}><i>{item.icon}</i>{item.label}</button>)}</nav><div className="sidebar-tip"><span>DATA QUALITY</span><p>Use verified stops and local businesses to keep guidance useful.</p></div><button className="sign-out" onClick={() => setToken("")}>↗ Sign out</button></aside><section className="workspace"><header className="topbar"><div><p className="eyebrow">ADMINISTRATIVE CONSOLE</p><h1>{activeTab.label}</h1><p className="page-subtitle">{tab === "overview" ? "Monitor and improve the local explorer experience." : `Manage ${activeTab.label.toLowerCase()} used by Cavite Explorer.`}</p></div><div className="header-actions"><span className="status-dot">All systems ready</span><button className="secondary" onClick={load}>↻ Refresh data</button></div></header>{message && <p className="toast">{message}<button onClick={() => setMessage("")}>×</button></p>}{tab === "overview" && <Overview count={count} setTab={setTab} />}{tab === "users" && <Users rows={data.users} api={api} reload={load} />}{tab === "places" && <><Form title="Add a landmark" subtitle="Create a verified destination for explorers." fields={["name", "municipality", "barangay", "description", "category", "latitude", "longitude"]} save={save("/admin/places")} /><Table title="Saved landmarks" rows={data.places} fields={["name", "municipality", "barangay", "category", "latitude", "longitude"]} /></>}{tab === "transport" && <TransportWorkspace routes={data.routes} terminals={data.tricycleTerminals} api={api} reload={load} setMessage={setMessage} />}{tab === "partners" && <><Form title="Add a partner business" subtitle="List a place where explorers can use earned badge benefits." fields={["name", "category", "address", "municipality", "contact"]} save={save("/admin/businesses")} /><Table title="Partner businesses" rows={data.businesses} fields={["name", "category", "address", "municipality", "contact"]} /></>}{tab === "offers" && <><Form title="Create a badge reward" subtitle="Connect an explorer badge to a clear partner benefit." fields={["businessId", "badgeLandmarkId", "title", "description", "discountLabel"]} save={save("/admin/offers")} /><Table title="Active rewards" rows={data.offers} fields={["title", "discountLabel", "description"]} /></>}</section></main>;
}

function Overview({ count, setTab }: { count: (key: string) => number; setTab: (tab: Tab) => void }) { const stats = [["Landmarks", count("places"), "⌖", "places"], ["Transport stops", count("stops"), "↝", "transport"], ["Partner places", count("businesses"), "♧", "partners"], ["Live rewards", count("offers"), "✦", "offers"]] as const; return <><section className="hero"><div><p className="eyebrow">TODAY’S PRIORITY</p><h2>Make every route feel confidently local.</h2><p>Start with the boarding and transfer points people actually use. This gives your explorers clearer guidance and a more reliable map.</p><button className="primary" onClick={() => setTab("transport")}>Add transport data <span>→</span></button></div><div className="hero-route"><span className="route-stop start">Start</span><i></i><span className="route-stop transfer">Transfer</span><i></i><span className="route-stop end">Explore</span></div></section><section className="stats-grid">{stats.map(([label, value, icon, destination]) => <button className="metric" key={label} onClick={() => setTab(destination)}><i>{icon}</i><span>{label}</span><strong>{value}</strong><small>View details →</small></button>)}</section><section className="overview-grid"><article className="checklist card"><div className="section-heading"><div><p className="eyebrow">RECOMMENDED ORDER</p><h2>Build a trusted network</h2></div><span className="pill">Getting started</span></div><ol><li><b>1</b><div><strong>Add landmarks</strong><p>Define the places explorers can discover.</p></div><button onClick={() => setTab("places")}>Open</button></li><li><b>2</b><div><strong>Add verified stops</strong><p>Mark where commuters board and transfer.</p></div><button onClick={() => setTab("transport")}>Open</button></li><li><b>3</b><div><strong>Add local rewards</strong><p>Give badge holders a reason to explore further.</p></div><button onClick={() => setTab("offers")}>Open</button></li></ol></article><article className="activity card"><p className="eyebrow">AT A GLANCE</p><h2>Your current coverage</h2>{[["Destinations",count("places")],["Transport",count("stops")],["Rewards",count("offers")]].map(([label,value])=><div className="coverage" key={label as string}><span>{label}</span><div><i style={{width:`${Math.min((value as number)*10,100)}%`}} /></div><b>{value}</b></div>)}<p className="activity-note">Coverage grows as you add approved local information.</p></article></section></>; }

type RoutePoint = [number, number];
type RouteDirection = "outbound" | "inbound";
type RoadAnchor = { point: RoutePoint; name: string };
type AccessPoint = { point: RoutePoint; name: string; roadName: string; type: "boarding" | "transfer" };
type MapTool = "start" | "end" | "waypoint" | "road" | "boarding" | "transfer";
type RouteOption = { geometry: RoutePoint[]; roads: string[]; roadAnchors: RoadAnchor[]; distance: number; duration: number };

function TransportWorkspace({ routes, terminals, api, reload, setMessage }: { routes: any[]; terminals: any[]; api: (path: string, opts?: RequestInit) => Promise<any>; reload: () => void; setMessage: (message: string) => void }) {
  const mapElement = useRef<HTMLDivElement>(null);
  const mapRef = useRef<any>(null);
  const layerRef = useRef<any>(null);
  const mapSearchCache = useRef(new Map<string, MapSearchResult[]>());
  const lastMapSearchAt = useRef(0);
  const municipalityLookupIds = useRef({ origin: 0, destination: 0 });
  const pathsRef = useRef<Record<RouteDirection, RouteOption | null>>({ outbound: null, inbound: null });
  const toolRef = useRef<MapTool>("start");
  const directionRef = useRef<RouteDirection>("outbound");
  const [editingId, setEditingId] = useState<string | null>(null);
  const [name, setName] = useState("");
  const [mode, setMode] = useState("Jeepney");
  const [outboundSignboard, setOutboundSignboard] = useState("");
  const [inboundSignboard, setInboundSignboard] = useState("");
  const [originName, setOriginName] = useState("");
  const [originMunicipality, setOriginMunicipality] = useState("");
  const [originRoadName, setOriginRoadName] = useState("");
  const [destinationName, setDestinationName] = useState("");
  const [destinationMunicipality, setDestinationMunicipality] = useState("");
  const [destinationRoadName, setDestinationRoadName] = useState("");
  const [origin, setOrigin] = useState<RoutePoint | null>(null);
  const [destination, setDestination] = useState<RoutePoint | null>(null);
  const [direction, setDirection] = useState<RouteDirection>("outbound");
  const [tool, setTool] = useState<MapTool>("start");
  const [waypoints, setWaypoints] = useState<Record<RouteDirection, RoutePoint[]>>({ outbound: [], inbound: [] });
  const [alternatives, setAlternatives] = useState<Record<RouteDirection, RouteOption[]>>({ outbound: [], inbound: [] });
  const [selected, setSelected] = useState<Record<RouteDirection, number>>({ outbound: -1, inbound: -1 });
  const [paths, setPaths] = useState<Record<RouteDirection, RouteOption | null>>({ outbound: null, inbound: null });
  const [accessPoints, setAccessPoints] = useState<Record<RouteDirection, AccessPoint[]>>({ outbound: [], inbound: [] });
  const [baseFare, setBaseFare] = useState("14");
  const [baseDistanceKm, setBaseDistanceKm] = useState("4");
  const [additionalFarePerKm, setAdditionalFarePerKm] = useState("2");
  const [fareNotes, setFareNotes] = useState("");
  const [notes, setNotes] = useState("");
  const [isBidirectional, setIsBidirectional] = useState(true);
  const [routing, setRouting] = useState(false);
  const [deletingId, setDeletingId] = useState<string | null>(null);
  const [routeError, setRouteError] = useState("");
  const [mapSearchQuery, setMapSearchQuery] = useState("");
  const [mapSearchResults, setMapSearchResults] = useState<MapSearchResult[]>([]);
  const [mapSearching, setMapSearching] = useState(false);
  const [mapSearchError, setMapSearchError] = useState("");
  const [transportSection, setTransportSection] = useState<"fixed" | "tricycle">("fixed");

  useEffect(() => { toolRef.current = tool; }, [tool]);
  useEffect(() => { directionRef.current = direction; }, [direction]);
  useEffect(() => { pathsRef.current = paths; }, [paths]);

  const suggestTerminalMunicipality = async (terminal: "origin" | "destination", point: RoutePoint) => {
    const lookupId = ++municipalityLookupIds.current[terminal];
    try {
      const params = new URLSearchParams({
        format: "jsonv2",
        lat: String(point[0]),
        lon: String(point[1]),
        zoom: "14",
        addressdetails: "1",
      });
      const response = await fetch(`https://nominatim.openstreetmap.org/reverse?${params.toString()}`);
      if (!response.ok) return;
      const result = await response.json();
      if (municipalityLookupIds.current[terminal] !== lookupId) return;
      const municipality = municipalityFromReverseGeocode(result);
      if (!municipality) return;
      if (terminal === "origin") setOriginMunicipality(municipality);
      else setDestinationMunicipality(municipality);
    } catch {
      // Coordinates remain usable and the municipality dropdown stays editable.
    }
  };

  useEffect(() => {
    if (origin) void suggestTerminalMunicipality("origin", origin);
  }, [origin]);

  useEffect(() => {
    if (destination) void suggestTerminalMunicipality("destination", destination);
  }, [destination]);

  const snapToRoute = (point: RoutePoint, geometry?: RoutePoint[]) => {
    if (!geometry?.length) return point;
    return geometry.reduce((closest, candidate) => {
      const closestDistance = (closest[0] - point[0]) ** 2 + (closest[1] - point[1]) ** 2;
      const candidateDistance = (candidate[0] - point[0]) ** 2 + (candidate[1] - point[1]) ** 2;
      return candidateDistance < closestDistance ? candidate : closest;
    });
  };

  const updateSharedRoadAnchors = (update: (anchors: RoadAnchor[]) => RoadAnchor[]) => {
    setPaths((current) => {
      const source = current.outbound?.roadAnchors.length ? current.outbound.roadAnchors : current.inbound?.roadAnchors || [];
      const geometry = current.outbound?.geometry || current.inbound?.geometry || [];
      const routeIndex = (anchor: RoadAnchor) => geometry.reduce((best, point, index) => {
        const distance = (point[0] - anchor.point[0]) ** 2 + (point[1] - anchor.point[1]) ** 2;
        return distance < best.distance ? { index, distance } : best;
      }, { index: 0, distance: Number.POSITIVE_INFINITY }).index;
      const roadAnchors = update(source).sort((first, second) => routeIndex(first) - routeIndex(second));
      return {
        outbound: current.outbound ? { ...current.outbound, roadAnchors } : null,
        inbound: current.inbound ? { ...current.inbound, roadAnchors } : null,
      };
    });
  };

  useEffect(() => {
    const shared = paths.outbound?.roadAnchors;
    if (shared && paths.inbound && paths.inbound.roadAnchors !== shared) {
      setPaths((current) => ({ ...current, inbound: current.inbound ? { ...current.inbound, roadAnchors: shared } : null }));
    }
  }, [paths.outbound?.roadAnchors, paths.inbound]);

  const resetBuilder = () => {
    setEditingId(null); setName(""); setMode("Jeepney"); setOutboundSignboard(""); setInboundSignboard("");
    setOriginName(""); setOriginMunicipality(""); setOriginRoadName(""); setDestinationName(""); setDestinationMunicipality(""); setDestinationRoadName(""); setOrigin(null); setDestination(null); setDirection("outbound"); setTool("start");
    setWaypoints({ outbound: [], inbound: [] }); setAlternatives({ outbound: [], inbound: [] }); setSelected({ outbound: -1, inbound: -1 });
    setPaths({ outbound: null, inbound: null }); setAccessPoints({ outbound: [], inbound: [] }); setBaseFare("14"); setBaseDistanceKm("4"); setAdditionalFarePerKm("2"); setFareNotes(""); setNotes(""); setIsBidirectional(true); setRouteError("");
    setMapSearchQuery(""); setMapSearchResults([]); setMapSearchError("");
    mapRef.current?.setView([14.2456, 120.8786], 10);
  };

  const searchTransportMap = async () => {
    const query = mapSearchQuery.trim();
    if (query.length < 3) { setMapSearchError("Enter at least 3 characters."); return; }
    const cacheKey = query.toLowerCase();
    const cached = mapSearchCache.current.get(cacheKey);
    if (cached) { setMapSearchResults(cached); setMapSearchError(cached.length ? "" : "No matching place found in Cavite."); return; }
    if (Date.now() - lastMapSearchAt.current < 1000) { setMapSearchError("Please wait a moment before searching again."); return; }
    lastMapSearchAt.current = Date.now();
    setMapSearching(true); setMapSearchError(""); setMapSearchResults([]);
    try {
      const params = new URLSearchParams({ format: "jsonv2", q: `${query}, Philippines`, limit: "6", countrycodes: "ph", addressdetails: "1", viewbox: "120.70,14.70,121.20,13.80" });
      const response = await fetch(`https://nominatim.openstreetmap.org/search?${params.toString()}`);
      if (!response.ok) throw Error("Map search is temporarily unavailable.");
      const results = (await response.json()) as MapSearchResult[];
      mapSearchCache.current.set(cacheKey, results);
      setMapSearchResults(results);
      if (!results.length) setMapSearchError("No matching place found in Cavite.");
    } catch (error: any) { setMapSearchError(error.message || "Map search is temporarily unavailable."); }
    finally { setMapSearching(false); }
  };

  const selectTransportMapResult = (result: MapSearchResult) => {
    const point: RoutePoint = [Number(result.lat), Number(result.lon)];
    mapRef.current?.setView(point, 17);
    setMapSearchQuery(result.display_name.split(",").slice(0, 3).join(","));
    setMapSearchResults([]); setMapSearchError("");
  };

  useEffect(() => {
    if (!mapElement.current) return;
    let disposed = false;
    import("leaflet").then((L) => {
      if (disposed || !mapElement.current) return;
      const map = L.map(mapElement.current, { scrollWheelZoom: true }).setView([14.2456, 120.8786], 10);
      L.tileLayer("https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png", { attribution: "&copy; OpenStreetMap contributors", maxZoom: 19 }).addTo(map);
      mapRef.current = map;
      layerRef.current = L.layerGroup().addTo(map);
      map.on("click", (event: any) => {
        const point: RoutePoint = [event.latlng.lat, event.latlng.lng];
        const activePath = pathsRef.current[directionRef.current];
        if (toolRef.current === "start") { setOrigin(point); setTool("end"); }
        else if (toolRef.current === "end") { setDestination(point); setTool("waypoint"); }
        else if (toolRef.current === "waypoint") setWaypoints((current) => ({ ...current, [directionRef.current]: [...current[directionRef.current], point] }));
        else if (!activePath) setRouteError("Select the blue route before adding route markers.");
        else if (toolRef.current === "road") { const snapped = snapToRoute(point, activePath.geometry); updateSharedRoadAnchors((anchors) => [...anchors, { point: snapped, name: "Unnamed road" }]); }
        else { const snapped = snapToRoute(point, activePath.geometry); setAccessPoints((current) => ({ ...current, [directionRef.current]: [...current[directionRef.current], { point: snapped, name: "", roadName: "", type: toolRef.current === "transfer" ? "transfer" : "boarding" }] })); }
      });
      setTimeout(() => map.invalidateSize(), 0);
    });
    return () => { disposed = true; mapRef.current?.remove(); mapRef.current = null; layerRef.current = null; };
  }, []);

  useEffect(() => {
    const map = mapRef.current; const layer = layerRef.current;
    if (!map || !layer) return;
    let cancelled = false;
    import("leaflet").then((L) => {
      if (cancelled || !layerRef.current) return;
      layer.clearLayers();
      const makePin = (point: RoutePoint, label: string, color: string, onMove: (point: RoutePoint) => void, onDelete?: () => void) => {
        const icon = L.divIcon({ className: "transport-pin-shell", html: `<span style="background:${color}">${label}</span>`, iconSize: [34, 42], iconAnchor: [17, 38] });
        const marker = L.marker(point, { icon, draggable: true }).addTo(layer);
        marker.on("dragend", () => { const value = marker.getLatLng(); onMove([value.lat, value.lng]); });
        if (onDelete) marker.on("click", (event: any) => { L.DomEvent.stop(event.originalEvent); onDelete(); });
      };
      if (origin) makePin(origin, "A", "#15704f", (point) => { setOrigin(point); setPaths((value) => ({ ...value, outbound: null, inbound: null })); });
      if (destination) makePin(destination, "B", "#d94c3d", (point) => { setDestination(point); setPaths((value) => ({ ...value, outbound: null, inbound: null })); });
      waypoints[direction].forEach((point, index) => {
        makePin(point, `G${index + 1}`, "#d89b2b", (next) => {
          setWaypoints((value) => ({
            ...value,
            [direction]: value[direction].map((item, itemIndex) => itemIndex === index ? next : item),
          }));
        }, () => setWaypoints((value) => ({ ...value, [direction]: value[direction].filter((_, itemIndex) => itemIndex !== index) })));
      });
      accessPoints[direction].forEach((item, index) => {
        makePin(item.point, item.type === "transfer" ? "T" : "P", item.type === "transfer" ? "#e56b24" : "#6b4bc3", (next) => {
          const snapped = snapToRoute(next, paths[direction]?.geometry);
          setAccessPoints((value) => ({ ...value, [direction]: value[direction].map((current, itemIndex) => itemIndex === index ? { ...current, point: snapped } : current) }));
        });
      });
      paths[direction]?.roadAnchors.forEach((anchor, index) => {
        const icon = L.divIcon({ className: "road-anchor-pin-shell", html: `<span>R${index + 1}</span>`, iconSize: [28, 28], iconAnchor: [14, 14] });
        const marker = L.marker(anchor.point, { icon, draggable: true })
          .bindTooltip(`${anchor.name || "Unnamed road"}`, { permanent: true, direction: "top", offset: [0, -10], className: "road-anchor-label" })
          .addTo(layer);
        marker.on("dragend", () => { const value = marker.getLatLng(); const snapped = snapToRoute([value.lat, value.lng], paths[direction]?.geometry); marker.setLatLng(snapped); updateSharedRoadAnchors((anchors) => anchors.map((item, itemIndex) => itemIndex === index ? { ...item, point: snapped } : item)); });
        marker.on("click", (event: any) => { L.DomEvent.stop(event.originalEvent); updateSharedRoadAnchors((anchors) => anchors.filter((_, itemIndex) => itemIndex !== index)); });
      });
      alternatives[direction].forEach((option, index) => {
        const active = selected[direction] === index;
        const polyline = L.polyline(option.geometry, { color: active ? "#2478ff" : index % 2 ? "#e39b35" : "#dc5548", weight: active ? 7 : 5, opacity: active ? .95 : .58 }).addTo(layer);
        polyline.on("click", () => { setSelected((value) => ({ ...value, [direction]: index })); setPaths((value) => ({ ...value, [direction]: option })); });
      });
      if (!alternatives[direction].length && paths[direction]) L.polyline(paths[direction]!.geometry, { color: "#2478ff", weight: 7, opacity: .95 }).addTo(layer);
    });
    return () => { cancelled = true; };
  }, [origin, destination, direction, waypoints, accessPoints, alternatives, selected, paths]);

  const generateRoutes = async () => {
    if (!origin || !destination) { setRouteError("Place both terminal pins first."); return; }
    setRouting(true); setRouteError("");
    const terminals = direction === "outbound" ? [origin, destination] : [destination, origin];
    const points = [terminals[0], ...waypoints[direction], terminals[1]];
    const coordinates = points.map((point) => `${point[1]},${point[0]}`).join(";");
    try {
      const response = await fetch(`https://router.project-osrm.org/route/v1/driving/${coordinates}?alternatives=true&overview=full&geometries=geojson&steps=true`);
      if (!response.ok) throw Error("The route service is temporarily unavailable.");
      const result = await response.json();
      const options: RouteOption[] = (result.routes || []).map((route: any) => ({
        geometry: route.geometry.coordinates.map((point: number[]) => [point[1], point[0]] as RoutePoint),
        roads: Array.from(new Set<string>((route.legs || []).flatMap((leg: any) => (leg.steps || []).map((step: any) => String(step.name || "").trim()).filter(Boolean)))),
        roadAnchors: (route.legs || []).flatMap((leg: any) => (leg.steps || []).map((step: any) => {
          const coordinate = step.geometry?.coordinates?.[0];
          return coordinate && String(step.name || "").trim() ? { point: [Number(coordinate[1]), Number(coordinate[0])] as RoutePoint, name: String(step.name).trim() } : null;
        }).filter((anchor: RoadAnchor | null) => anchor && !waypoints[direction].some((guidePoint) => (guidePoint[0] - anchor.point[0]) ** 2 + (guidePoint[1] - anchor.point[1]) ** 2 < 0.00000004))),
        distance: Number(route.distance || 0), duration: Number(route.duration || 0),
      }));
      if (!options.length) throw Error("No road route was found between those pins.");
      setAlternatives((value) => ({ ...value, [direction]: options }));
      setSelected((value) => ({ ...value, [direction]: 0 }));
      setPaths((value) => ({ ...value, [direction]: options[0] }));
      const bounds = points.map((point) => [point[0], point[1]] as [number, number]);
      mapRef.current?.fitBounds(bounds, { padding: [35, 35] });
    } catch (error: any) { setRouteError(error.message || "Could not generate route alternatives."); }
    finally { setRouting(false); }
  };

  const copyOutboundToInbound = () => {
    if (!paths.outbound) { setRouteError("Select the outbound path first."); return; }
    const inbound = { ...paths.outbound, geometry: [...paths.outbound.geometry].reverse(), roads: [...paths.outbound.roads].reverse(), roadAnchors: paths.outbound.roadAnchors };
    setPaths((value) => ({ ...value, inbound })); setAlternatives((value) => ({ ...value, inbound: [] })); setSelected((value) => ({ ...value, inbound: -1 })); setDirection("inbound"); setRouteError("");
  };

  const removeLastWaypoint = () => setWaypoints((value) => ({ ...value, [direction]: value[direction].slice(0, -1) }));

  const saveRoute = async (event: FormEvent) => {
    event.preventDefault();
    if (!origin || !destination || !paths.outbound) { setRouteError("Complete the terminal pins and select an outbound route before saving."); return; }
    if (isBidirectional && !paths.inbound) { setRouteError("Generate the return direction or copy the outbound path in reverse."); return; }
    const payload = {
      name, mode, outboundSignboard, inboundSignboard, originName, originMunicipality, originRoadName, destinationName, destinationMunicipality, destinationRoadName,
      originLatitude: origin[0], originLongitude: origin[1], destinationLatitude: destination[0], destinationLongitude: destination[1],
      outboundGeometry: paths.outbound.geometry, inboundGeometry: isBidirectional ? paths.inbound?.geometry : null,
      outboundRoads: paths.outbound.roads, inboundRoads: isBidirectional ? paths.inbound?.roads || [] : [],
      outboundRoadAnchors: paths.outbound.roadAnchors, inboundRoadAnchors: isBidirectional ? paths.outbound.roadAnchors : [],
      outboundAccessPoints: accessPoints.outbound, inboundAccessPoints: isBidirectional ? accessPoints.inbound : [],
      isBidirectional, baseFare, baseDistanceKm, additionalFarePerKm, fareNotes, notes, isActive: true,
    };
    try {
      await api(`/admin/transport/routes${editingId ? `/${editingId}` : ""}`, { method: editingId ? "PATCH" : "POST", body: JSON.stringify(payload) });
      setMessage(editingId ? "Verified transport route updated." : "Verified transport route created."); resetBuilder(); reload();
    } catch (error: any) { setRouteError(error.message || "Could not save the transport route."); }
  };

  const editRoute = (route: any) => {
    const sharedRoadAnchors: RoadAnchor[] = Array.isArray(route.outboundRoadAnchors) && route.outboundRoadAnchors.length ? route.outboundRoadAnchors : Array.isArray(route.inboundRoadAnchors) ? route.inboundRoadAnchors : [];
    const outbound: RouteOption | null = Array.isArray(route.outboundGeometry) ? { geometry: route.outboundGeometry, roads: route.outboundRoads || [], roadAnchors: sharedRoadAnchors, distance: 0, duration: 0 } : null;
    const inbound: RouteOption | null = Array.isArray(route.inboundGeometry) ? { geometry: route.inboundGeometry, roads: route.inboundRoads || [], roadAnchors: sharedRoadAnchors, distance: 0, duration: 0 } : null;
    setEditingId(route.id); setName(route.name || ""); setMode(route.mode || "Jeepney"); setOutboundSignboard(route.outboundSignboard || ""); setInboundSignboard(route.inboundSignboard || "");
    setOriginName(route.originName || ""); setOriginMunicipality(route.originMunicipality || ""); setOriginRoadName(route.originRoadName || ""); setDestinationName(route.destinationName || ""); setDestinationMunicipality(route.destinationMunicipality || ""); setDestinationRoadName(route.destinationRoadName || "");
    setOrigin(Number.isFinite(route.originLatitude) && Number.isFinite(route.originLongitude) ? [route.originLatitude, route.originLongitude] : null);
    setDestination(Number.isFinite(route.destinationLatitude) && Number.isFinite(route.destinationLongitude) ? [route.destinationLatitude, route.destinationLongitude] : null);
    setPaths({ outbound, inbound }); setAlternatives({ outbound: [], inbound: [] }); setSelected({ outbound: -1, inbound: -1 }); setWaypoints({ outbound: [], inbound: [] });
    setAccessPoints({ outbound: Array.isArray(route.outboundAccessPoints) ? route.outboundAccessPoints : [], inbound: Array.isArray(route.inboundAccessPoints) ? route.inboundAccessPoints : [] });
    setBaseFare(route.baseFare == null ? "" : String(route.baseFare)); setBaseDistanceKm(route.baseDistanceKm == null ? "4" : String(route.baseDistanceKm)); setAdditionalFarePerKm(route.additionalFarePerKm == null ? "" : String(route.additionalFarePerKm)); setFareNotes(route.fareNotes || ""); setNotes(route.notes || ""); setIsBidirectional(route.isBidirectional !== false); setDirection("outbound"); setRouteError("");
    if (outbound?.geometry.length) mapRef.current?.fitBounds(outbound.geometry, { padding: [35, 35] });
    window.scrollTo({ top: 0, behavior: "smooth" });
  };

  const deleteRoute = async (route: any) => {
    if (!window.confirm(`Delete "${route.name}"? This removes its mapped paths and verified transport data.`)) return;
    setDeletingId(route.id); setRouteError("");
    try {
      await api(`/admin/transport/routes/${route.id}`, { method: "DELETE" });
      if (editingId === route.id) resetBuilder();
      setMessage(`Route "${route.name}" was deleted.`); reload();
    } catch (error: any) { setRouteError(error.message || "Could not delete the route."); }
    finally { setDeletingId(null); }
  };

  const currentPath = paths[direction];
  return <>
    <section className="transport-workspace-switch" aria-label="Transport data type">
      <button type="button" className={transportSection === "fixed" ? "active" : ""} onClick={() => setTransportSection("fixed")}><span>↝</span><div><strong>Fixed routes</strong><small>Jeepney, bus, UV, multicab</small></div></button>
      <button type="button" className={transportSection === "tricycle" ? "active" : ""} onClick={() => setTransportSection("tricycle")}><span>🛺</span><div><strong>Tricycle terminals</strong><small>Coverage-based, no fixed road line</small></div></button>
    </section>
    {transportSection === "fixed" && <>
    <section className="card transport-builder">
      <div className="section-heading transport-builder-heading"><div><p className="eyebrow">VERIFIED ROUTE BUILDER</p><h2>{editingId ? "Update transport route" : "Map the actual route"}</h2><p>Define the service, pin both terminals, and verify the exact road path.</p></div>{editingId && <div className="editing-route-badge"><span>Editing route</span><button type="button" className="secondary" onClick={resetBuilder}>Cancel</button></div>}</div>
      <form onSubmit={saveRoute}>
        <section className="route-form-section">
          <div className="route-form-title"><span>1</span><div><strong>Route information</strong><small>Name the service and record what passengers see on the signboard.</small></div></div>
          <div className="transport-details-grid route-identity-grid">
          <label>Route name<input value={name} onChange={(event) => setName(event.target.value)} placeholder="Paliparan–Zapote Talaba" required /></label>
          <label>Transport type<select value={mode} onChange={(event) => { const nextMode = event.target.value; setMode(nextMode); if (nextMode === "Jeepney") { setBaseFare("14"); setBaseDistanceKm("4"); setAdditionalFarePerKm("2"); } else if (nextMode === "Modern Jeepney") { setBaseFare("17"); setBaseDistanceKm("4"); setAdditionalFarePerKm("2.40"); } }}><option>Jeepney</option><option>Modern Jeepney</option><option>Bus</option><option>Multicab</option><option>UV Express</option></select></label>
          <label>Outbound signboard<input value={outboundSignboard} onChange={(event) => setOutboundSignboard(event.target.value)} placeholder="ZAPOTE" required /></label>
          <label>Inbound signboard<input value={inboundSignboard} onChange={(event) => setInboundSignboard(event.target.value)} placeholder="PALIPARAN" required={isBidirectional} disabled={!isBidirectional} /></label>
          </div>
          <label className="transport-checkbox"><input type="checkbox" checked={isBidirectional} onChange={(event) => setIsBidirectional(event.target.checked)} /><span><strong>Bidirectional route</strong><small>Passengers can use this service from A to B and B to A.</small></span></label>
        </section>
        <section className="route-form-section">
          <div className="route-form-title"><span>2</span><div><strong>Route terminals</strong><small>Municipalities are detected automatically when you place or move the pins.</small></div></div>
          <div className="terminal-details-grid">
            <article className="terminal-details-card terminal-a"><div className="terminal-card-heading"><b>A</b><div><strong>Starting terminal</strong><small>Outbound origin</small></div></div><div className="terminal-fields"><label>City / municipality<input list="route-municipality-options" value={originMunicipality} onChange={(event) => setOriginMunicipality(event.target.value)} placeholder="Detected from terminal A pin" required /></label><label>Terminal name<input value={originName} onChange={(event) => setOriginName(event.target.value)} placeholder="Paliparan Terminal" required /></label><label className="terminal-road-field">Road name<input value={originRoadName} onChange={(event) => setOriginRoadName(event.target.value)} placeholder="Exact road where passengers board" required /></label></div></article>
            <article className="terminal-details-card terminal-b"><div className="terminal-card-heading"><b>B</b><div><strong>Destination terminal</strong><small>Outbound destination</small></div></div><div className="terminal-fields"><label>City / municipality<input list="route-municipality-options" value={destinationMunicipality} onChange={(event) => setDestinationMunicipality(event.target.value)} placeholder="Detected from terminal B pin" required /></label><label>Terminal name<input value={destinationName} onChange={(event) => setDestinationName(event.target.value)} placeholder="Zapote Terminal" required /></label><label className="terminal-road-field">Road name<input value={destinationRoadName} onChange={(event) => setDestinationRoadName(event.target.value)} placeholder="Exact road where passengers get off" required /></label></div></article>
          </div>
          <datalist id="route-municipality-options">{routeMunicipalitySuggestions.map((municipality) => <option key={municipality} value={municipality} />)}</datalist>
        </section>
        <section className="route-form-section route-fare-section">
          <div className="route-form-title"><span>3</span><div><strong>Fare information</strong><small>Use the verified base fare and distance increment for this vehicle.</small></div></div>
          <div className="transport-details-grid fare-details-grid"><label>Base fare (₱)<input type="number" min="0" step="0.01" value={baseFare} onChange={(event) => setBaseFare(event.target.value)} placeholder="14" required /></label><label>Included distance (km)<input type="number" min="0.1" step="0.1" value={baseDistanceKm} onChange={(event) => setBaseDistanceKm(event.target.value)} placeholder="4" required /></label><label>Additional fare / km (₱)<input type="number" min="0" step="0.01" value={additionalFarePerKm} onChange={(event) => setAdditionalFarePerKm(event.target.value)} placeholder="2.00" required /></label><label>Fare notes<input value={fareNotes} onChange={(event) => setFareNotes(event.target.value)} placeholder="Optional passenger or fare notes" /></label></div>
        </section>
        <div className="transport-direction-tabs"><button type="button" className={direction === "outbound" ? "active" : ""} onClick={() => setDirection("outbound")}>A → B · {outboundSignboard || "Outbound"}</button>{isBidirectional && <button type="button" className={direction === "inbound" ? "active" : ""} onClick={() => setDirection("inbound")}>B → A · {inboundSignboard || "Inbound"}</button>}</div>
        <div className="transport-map-layout">
          <div className="transport-map-panel">
            <div className="map-search transport-map-search"><div className="map-search-row"><input type="search" value={mapSearchQuery} onChange={(event) => setMapSearchQuery(event.target.value)} onKeyDown={(event) => { if (event.key === "Enter") { event.preventDefault(); searchTransportMap(); } }} placeholder="Search a terminal, road, landmark, or barangay" aria-label="Search the transport route map" /><button type="button" onClick={searchTransportMap} disabled={mapSearching}>{mapSearching ? "Searching..." : "Search map"}</button></div>{mapSearchError && <p className="map-search-message">{mapSearchError}</p>}{mapSearchResults.length > 0 && <div className="map-search-results" role="listbox" aria-label="Transport map search results">{mapSearchResults.map((result) => <button type="button" role="option" key={result.place_id} onClick={() => selectTransportMapResult(result)}><strong>{result.display_name.split(",")[0]}</strong><span>{result.display_name.split(",").slice(1).join(",").trim()}</span></button>)}</div>}<small className="map-search-attribution">Select a result to center the map, then use the active map tool. Search data: OpenStreetMap contributors.</small></div>
            <div className="transport-map-toolbar"><button type="button" className={tool === "start" ? "active" : ""} onClick={() => setTool("start")}>Place terminal A</button><button type="button" className={tool === "end" ? "active" : ""} onClick={() => setTool("end")}>Place terminal B</button><button type="button" className={tool === "waypoint" ? "active" : ""} onClick={() => setTool("waypoint")}>Add guide point</button><button type="button" className={tool === "road" ? "active" : ""} onClick={() => setTool("road")} disabled={!currentPath}>Add road marker</button><button type="button" className={tool === "boarding" ? "active" : ""} onClick={() => setTool("boarding")} disabled={!currentPath}>Add boarding point</button><button type="button" className={tool === "transfer" ? "active" : ""} onClick={() => setTool("transfer")} disabled={!currentPath}>Add transfer point</button><button type="button" onClick={removeLastWaypoint} disabled={!waypoints[direction].length}>Undo guide point</button></div>
            <div ref={mapElement} className="transport-route-map" aria-label="Map for building the verified transport route" />
            <p className="transport-map-help">G markers only guide the generated path and are never saved as roads. R markers are verified road names. Click a G or R marker to delete it. Boarding and transfer markers identify passenger access points.</p>
          </div>
          <aside className="route-choice-panel">
            <div><span className="direction-label">Editing</span><strong>{direction === "outbound" ? `${originName || "Terminal A"} → ${destinationName || "Terminal B"}` : `${destinationName || "Terminal B"} → ${originName || "Terminal A"}`}</strong></div>
            <button type="button" className="primary" onClick={generateRoutes} disabled={routing}>{routing ? "Finding alternatives…" : "Generate route alternatives"}</button>
            {direction === "inbound" && <button type="button" className="secondary" onClick={copyOutboundToInbound}>Use outbound roads in reverse</button>}
            <div className="route-alternatives">{alternatives[direction].map((option, index) => <button type="button" className={selected[direction] === index ? "route-option selected" : "route-option"} key={index} onClick={() => { setSelected((value) => ({ ...value, [direction]: index })); setPaths((value) => ({ ...value, [direction]: option })); }}><i style={{ background: selected[direction] === index ? "#2478ff" : index % 2 ? "#e39b35" : "#dc5548" }} /><span><strong>Option {index + 1}</strong><small>{(option.distance / 1000).toFixed(1)} km · {Math.round(option.duration / 60)} min</small></span><b>{selected[direction] === index ? "Selected" : "Choose"}</b></button>)}</div>
            {currentPath && <div className="selected-route-summary"><span>Selected verified path</span><strong>{currentPath.roads.length ? `${currentPath.roads.length} named roads` : "Route geometry ready"}</strong><small>The selected line will be stored and shown to mobile users.</small></div>}
            {currentPath?.roadAnchors.length ? <div className="route-metadata-editor"><strong>Shared road names for A↔B</strong><small>Changes apply to both directions. Drag R markers on the map, rename them here, or remove incorrect markers.</small>{currentPath.roadAnchors.map((anchor, index) => <div className="road-anchor-editor" key={`${index}`}><label>Road R{index + 1}<input value={anchor.name} onChange={(event) => updateSharedRoadAnchors((anchors) => anchors.map((item, itemIndex) => itemIndex === index ? { ...item, name: event.target.value } : item))} /></label><button type="button" onClick={() => updateSharedRoadAnchors((anchors) => anchors.filter((_, itemIndex) => itemIndex !== index))}>Remove</button></div>)}</div> : null}
            {accessPoints[direction].length ? <div className="route-metadata-editor"><strong>Verified access points</strong>{accessPoints[direction].map((item, index) => <div className="access-point-editor" key={index}><span>{item.type === "transfer" ? "Transfer" : "Boarding"} point {index + 1}</span><input value={item.name} placeholder="Point name" onChange={(event) => setAccessPoints((value) => ({ ...value, [direction]: value[direction].map((current, itemIndex) => itemIndex === index ? { ...current, name: event.target.value } : current) }))} /><input value={item.roadName} placeholder="Exact road name" onChange={(event) => setAccessPoints((value) => ({ ...value, [direction]: value[direction].map((current, itemIndex) => itemIndex === index ? { ...current, roadName: event.target.value } : current) }))} /><button type="button" onClick={() => setAccessPoints((value) => ({ ...value, [direction]: value[direction].filter((_, itemIndex) => itemIndex !== index) }))}>Remove</button></div>)}</div> : null}
          </aside>
        </div>
        <label className="transport-notes">Route notes<textarea value={notes} onChange={(event) => setNotes(event.target.value)} rows={3} placeholder="Operating hours, landmarks, loading rules, or passenger reminders" /></label>
        {routeError && <p className="form-message">{routeError}</p>}
        <div className="transport-save-row"><button className="primary" type="submit">{editingId ? "Save route changes" : "Publish verified route"} →</button><span>{paths.outbound ? "Outbound ready" : "Outbound missing"} · {!isBidirectional ? "One way" : paths.inbound ? "Inbound ready" : "Inbound missing"}</span></div>
      </form>
    </section>
    <section className="card transport-directory legacy-route-directory"><div className="section-heading"><div><p className="eyebrow">ROUTE DIRECTORY</p><h2>Saved transport routes</h2><p>Open a route to correct its terminals, signboards, or exact road path.</p></div><span className="record-count">{routes.length} {routes.length === 1 ? "route" : "routes"}</span></div>
      <div className="transport-route-list">{routes.length ? routes.map((route) => <article key={route.id}><div className="route-mode-badge">{route.mode || "Transport"}</div><div><strong>{route.name}</strong><p>{route.originName && route.destinationName ? `${route.originName} ⇄ ${route.destinationName}` : "Map path not configured"}</p><small>{route.outboundSignboard ? `Signboards: ${route.outboundSignboard}${route.inboundSignboard ? ` / ${route.inboundSignboard}` : ""}` : "No signboard recorded"}</small></div><div className="route-status"><span className={route.outboundGeometry ? "mapped" : "unmapped"}>{route.outboundGeometry ? "Mapped" : "Needs map"}</span><button type="button" className="secondary" onClick={() => editRoute(route)}>Edit route</button><button type="button" className="route-delete-button" disabled={deletingId === route.id} onClick={() => deleteRoute(route)}>{deletingId === route.id ? "Deleting…" : "Delete"}</button></div></article>) : <p className="empty">No transport routes yet. Build the first verified route above.</p>}</div>
    </section>
    <TransportRouteDirectory routes={routes} editRoute={editRoute} deleteRoute={deleteRoute} deletingId={deletingId} />
    </>}
    {transportSection === "tricycle" && <TricycleTerminalWorkspace terminals={terminals} api={api} reload={reload} setMessage={setMessage} />}
  </>;
}

function TransportRouteDirectory({ routes, editRoute, deleteRoute, deletingId }: { routes: any[]; editRoute: (route: any) => void; deleteRoute: (route: any) => void; deletingId: string | null }) {
  const [query, setQuery] = useState("");
  const [mode, setMode] = useState("All");
  const [municipality, setMunicipality] = useState("All");
  const modes = ["All", ...Array.from(new Set(routes.map((route) => String(route.mode || "Transport"))))];
  const municipalities = ["All", ...Array.from(new Set(routes.flatMap((route) => [route.originMunicipality, route.destinationMunicipality]).filter(Boolean).map(String))).sort()];
  const normalizedQuery = query.trim().toLowerCase();
  const filteredRoutes = routes.filter((route) => {
    const matchesMode = mode === "All" || String(route.mode || "Transport") === mode;
    const matchesMunicipality = municipality === "All" || route.originMunicipality === municipality || route.destinationMunicipality === municipality;
    const searchable = [route.name, route.originName, route.destinationName, route.originMunicipality, route.destinationMunicipality, route.outboundSignboard, route.inboundSignboard, route.mode].filter(Boolean).join(" ").toLowerCase();
    return matchesMode && matchesMunicipality && (!normalizedQuery || searchable.includes(normalizedQuery));
  });
  return <section className="card transport-directory searchable-directory">
    <div className="section-heading"><div><p className="eyebrow">ROUTE DIRECTORY</p><h2>Saved transport routes</h2><p>Search by route, terminal, or signboard and narrow the list by transport type.</p></div><span className="record-count">{filteredRoutes.length} of {routes.length}</span></div>
    <div className="directory-tools route-directory-tools"><label><span>Search routes</span><div className="directory-search-field"><span>⌕</span><input type="search" value={query} onChange={(event) => setQuery(event.target.value)} placeholder="Route, terminal, municipality, or signboard" />{query && <button type="button" onClick={() => setQuery("")} aria-label="Clear route search">×</button>}</div></label><label><span>Transport type</span><select value={mode} onChange={(event) => setMode(event.target.value)}>{modes.map((item) => <option key={item}>{item}</option>)}</select></label><label><span>Municipality served</span><select value={municipality} onChange={(event) => setMunicipality(event.target.value)}>{municipalities.map((item) => <option key={item}>{item}</option>)}</select></label><output>{filteredRoutes.length} of {routes.length} routes</output></div>
    <div className="transport-route-list">{filteredRoutes.length ? filteredRoutes.map((route) => <article key={route.id}><div className="route-mode-badge">{route.mode || "Transport"}</div><div><strong>{route.name}</strong><p>{route.originName && route.destinationName ? `${route.originName} ⇄ ${route.destinationName}` : "Map path not configured"}</p><small>{[route.originMunicipality, route.destinationMunicipality].filter(Boolean).length ? `Municipalities: ${[...new Set([route.originMunicipality, route.destinationMunicipality].filter(Boolean))].join(" · ")} · ` : ""}{route.outboundSignboard ? `Signboards: ${route.outboundSignboard}${route.inboundSignboard ? ` / ${route.inboundSignboard}` : ""}` : "No signboard recorded"}</small></div><div className="route-status"><span className={route.outboundGeometry ? "mapped" : "unmapped"}>{route.outboundGeometry ? "Mapped" : "Needs map"}</span><button type="button" className="secondary" onClick={() => editRoute(route)}>Edit route</button><button type="button" className="route-delete-button" disabled={deletingId === route.id} onClick={() => deleteRoute(route)}>{deletingId === route.id ? "Deleting…" : "Delete"}</button></div></article>) : <div className="directory-empty"><span>⌕</span><strong>No matching routes</strong><p>Try another search term, transport type, or municipality.</p></div>}</div>
  </section>;
}

function LegacyTricycleTerminalWorkspace({ terminals, api, reload, setMessage }: { terminals: any[]; api: (path: string, opts?: RequestInit) => Promise<any>; reload: () => void; setMessage: (message: string) => void }) {
  const [error, setError] = useState("");
  const [editingTerminal, setEditingTerminal] = useState<any>(null);
  const saveTerminal = async (event: FormEvent<HTMLFormElement>) => { event.preventDefault(); const form = event.currentTarget; const values = Object.fromEntries(new FormData(form)); try { const editing = Boolean(editingTerminal); await api(editing ? `/admin/transport/tricycle-terminals/${editingTerminal.id}` : '/admin/transport/tricycle-terminals', { method: editing ? 'PATCH' : 'POST', body: JSON.stringify(values) }); form.reset(); window.dispatchEvent(new Event('landmark-form-reset')); setEditingTerminal(null); setError(''); setMessage(editing ? 'Tricycle terminal updated.' : 'Tricycle terminal coverage saved.'); reload(); } catch (failure: any) { setError(failure.message || 'Could not save tricycle terminal.'); } };
  const edit = (terminal: any) => { setEditingTerminal(terminal); setError(''); window.setTimeout(() => document.querySelector('#tricycle-terminal-form')?.scrollIntoView({ behavior: 'smooth', block: 'start' }), 0); };
  useEffect(() => {
    const list = document.querySelector('.tricycle-terminal-workspace .transport-route-list');
    const onTerminalClick = (event: Event) => {
      if ((event.target as HTMLElement).closest('button')) return;
      const article = (event.target as HTMLElement).closest('article');
      if (!article || !list) return;
      const index = Array.from(list.querySelectorAll('article')).indexOf(article);
      if (index >= 0 && terminals[index]) edit(terminals[index]);
    };
    list?.addEventListener('click', onTerminalClick);
    return () => list?.removeEventListener('click', onTerminalClick);
  }, [terminals]);
  useEffect(() => {
    if (!editingTerminal) {
      const heading = document.querySelector<HTMLElement>('.tricycle-terminal-workspace .section-heading h2');
      const submit = document.querySelector<HTMLButtonElement>('.tricycle-terminal-workspace form button[type="submit"]');
      if (heading) heading.textContent = 'Set up a tricycle terminal';
      if (submit) submit.textContent = 'Save terminal coverage →';
      return;
    }
    const applyTerminalToForm = () => {
      const form = document.querySelector<HTMLFormElement>('.tricycle-terminal-workspace form');
      if (!form) return;
      const setValue = (name: string, value: unknown) => { const input = form.elements.namedItem(name) as HTMLInputElement | HTMLTextAreaElement | null; if (input) input.value = value == null ? '' : String(value); };
      const [operatingStart = '06:00', operatingEnd = '22:00'] = String(editingTerminal.operatingHours || '06:00–22:00').split(/[–-]/);
      setValue('name', editingTerminal.name); setValue('coverageRadiusKm', editingTerminal.coverageRadiusKm); setValue('municipality', editingTerminal.municipality); setValue('barangay', editingTerminal.barangay); setValue('fareMin', editingTerminal.fareMin); setValue('fareMax', editingTerminal.fareMax); setValue('operatingStart', operatingStart.trim()); setValue('operatingEnd', operatingEnd.trim()); setValue('returnAvailabilityNotice', editingTerminal.returnAvailabilityNotice); setValue('notes', editingTerminal.notes); setValue('latitude', editingTerminal.latitude); setValue('longitude', editingTerminal.longitude);
      document.querySelector('.tricycle-terminal-workspace .landmark-map')?.dispatchEvent(new CustomEvent('landmark-search-result', { detail: { latitude: Number(editingTerminal.latitude), longitude: Number(editingTerminal.longitude) } }));
      const heading = document.querySelector<HTMLElement>('.tricycle-terminal-workspace .section-heading h2');
      const submit = form.querySelector<HTMLButtonElement>('button[type="submit"]');
      if (heading) heading.textContent = `Edit ${editingTerminal.name}`;
      if (submit) submit.textContent = 'Save terminal changes →';
    };
    window.setTimeout(applyTerminalToForm, 0);
  }, [editingTerminal]);
  const remove = async (terminal: any) => { if (!window.confirm(`Delete \"${terminal.name}\"?`)) return; try { await api(`/admin/transport/tricycle-terminals/${terminal.id}`, { method: 'DELETE' }); setMessage(`Tricycle terminal \"${terminal.name}\" was deleted.`); reload(); } catch (failure: any) { setError(failure.message || 'Could not delete terminal.'); } };
  return <section className="card transport-directory tricycle-terminal-workspace"><div className="section-heading"><div><p className="eyebrow">ON-DEMAND TRICYCLE SERVICE</p><h2>Set up a tricycle terminal</h2><p>Pin its base, choose the area it serves, then add the local fare guidance. No fixed road path is needed.</p></div><span className="record-count">{terminals.length} terminal{terminals.length === 1 ? '' : 's'}</span></div><form onSubmit={saveTerminal} className="tricycle-terminal-form"><div className="tricycle-step-label"><b>1</b><span>Terminal location</span><small>This is where outbound trips begin.</small></div><MapPicker label="Pin the tricycle terminal" helper="Search for the terminal or click its exact loading point on the map. Municipality and barangay will be suggested automatically." /><div className="tricycle-step-label"><b>2</b><span>Service details</span><small>These details appear in the commuter guide.</small></div><div className="transport-details-grid"><label>Terminal name<input name="name" required placeholder="Avenida Rizal–Molino Road Terminal" /></label><label>Coverage radius (km)<input name="coverageRadiusKm" type="number" min="0.1" step="0.1" defaultValue="2" required /></label><label>Municipality<input name="municipality" required placeholder="Filled from the pin" /></label><label>Barangay<input name="barangay" placeholder="Filled from the pin" /></label><label>Estimated minimum fare<input name="fareMin" type="number" min="0" step="0.01" placeholder="30" /></label><label>Estimated maximum fare<input name="fareMax" type="number" min="0" step="0.01" placeholder="60" /></label><div className="tricycle-time-range"><label>Starts<input name="operatingStart" type="time" defaultValue="06:00" /></label><label>Ends<input name="operatingEnd" type="time" defaultValue="22:00" /></label></div><label>Return availability note<input name="returnAvailabilityNotice" defaultValue="Return trips depend on an available passing tricycle." /></label><input name="latitude" type="hidden" required /><input name="longitude" type="hidden" required /></div><label className="transport-notes">Terminal notes<textarea name="notes" rows={2} placeholder="Example: Fare varies by destination; confirm with the driver before boarding." /></label><div className="tricycle-save-row"><span>Outbound trips begin at this terminal. Return trips will be marked as availability-dependent.</span><button className="primary" type="submit">Save terminal coverage →</button></div></form>{error && <p className="form-message">{error}</p>}<div className="transport-route-list">{terminals.length ? terminals.map((terminal) => <article key={terminal.id}><div className="route-mode-badge">Tricycle</div><div><strong>{terminal.name}</strong><p>{terminal.municipality}{terminal.barangay ? ` · ${terminal.barangay}` : ''} · {terminal.coverageRadiusKm} km coverage</p><small>{terminal.fareMin != null ? `Estimated ₱${terminal.fareMin}${terminal.fareMax != null ? `–₱${terminal.fareMax}` : ''}` : 'Fare to be confirmed'} · {terminal.returnAvailabilityNotice}</small></div><div className="route-status"><span className="mapped">Coverage active</span><button type="button" className="route-delete-button" onClick={() => remove(terminal)}>Delete</button></div></article>) : <p className="empty">No tricycle terminals yet. Pin the first terminal above.</p>}</div></section>;
}

function TricycleTerminalWorkspace({ terminals, api, reload, setMessage }: { terminals: any[]; api: (path: string, opts?: RequestInit) => Promise<any>; reload: () => void; setMessage: (message: string) => void }) {
  const [editingTerminal, setEditingTerminal] = useState<any>(null);
  const [error, setError] = useState("");
  const [saving, setSaving] = useState(false);
  const [terminalQuery, setTerminalQuery] = useState("");
  const [municipalityFilter, setMunicipalityFilter] = useState("All");
  const municipalities = ["All", ...Array.from(new Set(terminals.map((terminal) => String(terminal.municipality || "Unspecified"))))];
  const normalizedTerminalQuery = terminalQuery.trim().toLowerCase();
  const filteredTerminals = terminals.filter((terminal) => {
    const matchesMunicipality = municipalityFilter === "All" || String(terminal.municipality || "Unspecified") === municipalityFilter;
    const searchable = [terminal.name, terminal.municipality, terminal.barangay, terminal.notes].filter(Boolean).join(" ").toLowerCase();
    return matchesMunicipality && (!normalizedTerminalQuery || searchable.includes(normalizedTerminalQuery));
  });
  const [operatingStart = "06:00", operatingEnd = "22:00"] = String(editingTerminal?.operatingHours || "06:00–22:00").split(/[–-]/);

  const cancelEditing = () => {
    setEditingTerminal(null);
    setError("");
    window.dispatchEvent(new Event("landmark-form-reset"));
  };

  const beginEditing = (terminal: any) => {
    setEditingTerminal(terminal);
    setError("");
    window.setTimeout(() => document.querySelector("#tricycle-terminal-editor")?.scrollIntoView({ behavior: "smooth", block: "start" }), 0);
  };

  const saveTerminal = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    const form = event.currentTarget;
    const values = Object.fromEntries(new FormData(form));
    setSaving(true);
    try {
      const isEditing = Boolean(editingTerminal);
      await api(isEditing ? `/admin/transport/tricycle-terminals/${editingTerminal.id}` : "/admin/transport/tricycle-terminals", {
        method: isEditing ? "PATCH" : "POST",
        body: JSON.stringify(values),
      });
      setMessage(isEditing ? `Terminal "${editingTerminal.name}" updated.` : "Tricycle terminal coverage saved.");
      setEditingTerminal(null);
      setError("");
      form.reset();
      window.dispatchEvent(new Event("landmark-form-reset"));
      reload();
    } catch (failure: any) {
      setError(failure.message || "Could not save tricycle terminal.");
    } finally {
      setSaving(false);
    }
  };

  const removeTerminal = async (terminal: any) => {
    if (!window.confirm(`Delete "${terminal.name}"?`)) return;
    try {
      await api(`/admin/transport/tricycle-terminals/${terminal.id}`, { method: "DELETE" });
      if (editingTerminal?.id === terminal.id) cancelEditing();
      setMessage(`Tricycle terminal "${terminal.name}" was deleted.`);
      reload();
    } catch (failure: any) {
      setError(failure.message || "Could not delete terminal.");
    }
  };

  return <section className="card transport-directory tricycle-terminal-workspace">
    <div className="section-heading">
      <div><p className="eyebrow">ON-DEMAND TRICYCLE SERVICE</p><h2>{editingTerminal ? "Update terminal coverage" : "Set up a tricycle terminal"}</h2><p>Pin its loading point, define its service radius, and keep its local fare guidance accurate.</p></div>
      <span className="record-count">{terminals.length} terminal{terminals.length === 1 ? "" : "s"}</span>
    </div>

    {editingTerminal && <div className="tricycle-edit-banner"><div><span>EDITING TERMINAL</span><strong>{editingTerminal.name}</strong><small>Update the form or move the map pin, then save your changes.</small></div><button type="button" className="secondary" onClick={cancelEditing}>Cancel edit</button></div>}

    <form key={editingTerminal?.id || "new-terminal"} id="tricycle-terminal-editor" onSubmit={saveTerminal} className="tricycle-terminal-form">
      <div className="tricycle-step-label"><b>1</b><span>Terminal location</span><small>Pin the exact place where passengers board.</small></div>
      <MapPicker latitude={editingTerminal?.latitude} longitude={editingTerminal?.longitude} accessPaths={editingTerminal?.accessPaths} showCoverageRadius enableAccessPathDrawing label="Pin the tricycle terminal" helper="Pin the loading point, then draw any real road connector that is missing or disconnected in OpenStreetMap." />

      <div className="tricycle-step-label"><b>2</b><span>Service details</span><small>These details appear in the commuter guide.</small></div>
      <div className="transport-details-grid">
        <label>Terminal name<input name="name" required defaultValue={editingTerminal?.name || ""} placeholder="Avenida Rizal–Molino Road Terminal" /></label>
        <label>Coverage radius (km)<input name="coverageRadiusKm" type="number" min="0.1" step="0.1" required defaultValue={editingTerminal?.coverageRadiusKm ?? 2} /></label>
        <label>Municipality<input name="municipality" required defaultValue={editingTerminal?.municipality || ""} placeholder="Filled from the pin" /></label>
        <label>Barangay<input name="barangay" defaultValue={editingTerminal?.barangay || ""} placeholder="Filled from the pin" /></label>
        <label>Estimated minimum fare<input name="fareMin" type="number" min="0" step="0.01" defaultValue={editingTerminal?.fareMin ?? ""} placeholder="30" /></label>
        <label>Estimated maximum fare<input name="fareMax" type="number" min="0" step="0.01" defaultValue={editingTerminal?.fareMax ?? ""} placeholder="60" /></label>
        <div className="tricycle-time-range"><label>Starts<input name="operatingStart" type="time" defaultValue={operatingStart.trim()} /></label><label>Ends<input name="operatingEnd" type="time" defaultValue={operatingEnd.trim()} /></label></div>
        <label>Return availability note<input name="returnAvailabilityNotice" defaultValue={editingTerminal?.returnAvailabilityNotice || "Return trips depend on an available passing tricycle."} /></label>
        <input name="latitude" type="hidden" required defaultValue={editingTerminal?.latitude ?? ""} />
        <input name="longitude" type="hidden" required defaultValue={editingTerminal?.longitude ?? ""} />
      </div>
      <label className="transport-notes">Terminal notes<textarea name="notes" rows={2} defaultValue={editingTerminal?.notes || ""} placeholder="Example: Fare varies by destination; confirm with the driver before boarding." /></label>
      {error && <p className="form-message">{error}</p>}
      <div className="tricycle-save-row"><span>{editingTerminal ? "Review the updated coverage before saving." : "Outbound trips begin here; return trips remain availability-dependent."}</span><div className="tricycle-form-actions">{editingTerminal && <button type="button" className="secondary" onClick={cancelEditing}>Cancel edit</button>}<button className="primary" type="submit" disabled={saving}>{saving ? "Saving…" : editingTerminal ? "Save changes →" : "Save terminal →"}</button></div></div>
    </form>

    <div className="tricycle-directory-heading"><div><span>SAVED TERMINALS</span><strong>Terminal coverage directory</strong></div><small>Select Edit to update a terminal and its map pin.</small></div>
    <div className="directory-tools"><label><span>Search terminals</span><div className="directory-search-field"><span>⌕</span><input type="search" value={terminalQuery} onChange={(event) => setTerminalQuery(event.target.value)} placeholder="Terminal, barangay, or municipality" />{terminalQuery && <button type="button" onClick={() => setTerminalQuery("")} aria-label="Clear terminal search">×</button>}</div></label><label><span>Municipality</span><select value={municipalityFilter} onChange={(event) => setMunicipalityFilter(event.target.value)}>{municipalities.map((municipality) => <option key={municipality}>{municipality}</option>)}</select></label><output>{filteredTerminals.length} of {terminals.length} terminals</output></div>
    <div className="transport-route-list filtered-terminal-list">{filteredTerminals.length ? filteredTerminals.map((terminal) => <article key={terminal.id} className={editingTerminal?.id === terminal.id ? "is-editing" : ""}><div className="route-mode-badge">Tricycle</div><div><strong>{terminal.name}</strong><p>{terminal.municipality}{terminal.barangay ? ` · ${terminal.barangay}` : ""} · {terminal.coverageRadiusKm} km coverage</p><small>{terminal.fareMin != null ? `Estimated ₱${terminal.fareMin}${terminal.fareMax != null ? `–₱${terminal.fareMax}` : ""}` : "Fare to be confirmed"} · {terminal.returnAvailabilityNotice}</small></div><div className="route-status"><span className="mapped">Coverage active</span><button type="button" className="secondary" onClick={() => beginEditing(terminal)}>Edit</button><button type="button" className="route-delete-button" onClick={() => removeTerminal(terminal)}>Delete</button></div></article>) : <div className="directory-empty"><span>⌕</span><strong>No matching terminals</strong><p>Try another search term or municipality.</p></div>}</div>
    <div className="transport-route-list">{terminals.length ? terminals.map((terminal) => <article key={terminal.id} className={editingTerminal?.id === terminal.id ? "is-editing" : ""}><div className="route-mode-badge">Tricycle</div><div><strong>{terminal.name}</strong><p>{terminal.municipality}{terminal.barangay ? ` · ${terminal.barangay}` : ""} · {terminal.coverageRadiusKm} km coverage</p><small>{terminal.fareMin != null ? `Estimated ₱${terminal.fareMin}${terminal.fareMax != null ? `–₱${terminal.fareMax}` : ""}` : "Fare to be confirmed"} · {terminal.returnAvailabilityNotice}</small></div><div className="route-status"><span className="mapped">Coverage active</span><button type="button" className="secondary" onClick={() => beginEditing(terminal)}>Edit</button><button type="button" className="route-delete-button" onClick={() => removeTerminal(terminal)}>Delete</button></div></article>) : <p className="empty">No tricycle terminals yet. Pin the first terminal above.</p>}</div>
  </section>;
}

function MapPicker({ latitude, longitude, accessPaths, showCoverageRadius = false, enableAccessPathDrawing = false, label = "Pin the landmark location", helper = "Search in Cavite or click the exact point on the map." }: { latitude?: number | string; longitude?: number | string; accessPaths?: unknown; showCoverageRadius?: boolean; enableAccessPathDrawing?: boolean; label?: string; helper?: string }) {
  const mapElement = useRef<HTMLDivElement>(null);
  const accessPathActions = useRef<{ start: () => void; finish: () => void; undo: () => void; clear: () => void } | null>(null);
  const searchCache = useRef(new Map<string, MapSearchResult[]>());
  const lastSearchAt = useRef(0);
  const hasInitialPin = Number.isFinite(Number(latitude)) && Number.isFinite(Number(longitude));
  const [coordinates, setCoordinates] = useState(hasInitialPin ? `${Number(latitude).toFixed(6)}, ${Number(longitude).toFixed(6)}` : "Click the map to place the landmark pin.");
  const [searchQuery, setSearchQuery] = useState("");
  const [searchResults, setSearchResults] = useState<MapSearchResult[]>([]);
  const [searching, setSearching] = useState(false);
  const [searchError, setSearchError] = useState("");
  const initialAccessPaths = Array.isArray(accessPaths) ? accessPaths : [];
  const [serializedAccessPaths, setSerializedAccessPaths] = useState(JSON.stringify(initialAccessPaths));
  const [drawingConnector, setDrawingConnector] = useState(false);
  const [connectorMessage, setConnectorMessage] = useState(initialAccessPaths.length ? `${initialAccessPaths.length} verified connector${initialAccessPaths.length === 1 ? "" : "s"} saved.` : "No verified connectors drawn yet.");

  const searchMap = async () => {
    const query = searchQuery.trim();
    if (query.length < 3) { setSearchError("Enter at least 3 characters."); return; }
    const cacheKey = query.toLowerCase();
    const cached = searchCache.current.get(cacheKey);
    if (cached) { setSearchResults(cached); setSearchError(cached.length ? "" : "No matching place found in Cavite."); return; }
    if (Date.now() - lastSearchAt.current < 1000) { setSearchError("Please wait a moment before searching again."); return; }
    lastSearchAt.current = Date.now();
    setSearching(true);
    setSearchError("");
    setSearchResults([]);
    try {
      const params = new URLSearchParams({ format: "jsonv2", q: `${query}, Cavite, Philippines`, limit: "6", countrycodes: "ph", addressdetails: "1", bounded: "1", viewbox: "120.55,14.55,121.15,13.85" });
      const response = await fetch(`https://nominatim.openstreetmap.org/search?${params.toString()}`);
      if (!response.ok) throw Error("Map search is temporarily unavailable.");
      const results = (await response.json()) as MapSearchResult[];
      searchCache.current.set(cacheKey, results);
      setSearchResults(results);
      if (!results.length) setSearchError("No matching place found in Cavite.");
    } catch (error: any) { setSearchError(error.message || "Map search is temporarily unavailable."); }
    finally { setSearching(false); }
  };

  const selectSearchResult = (result: MapSearchResult) => {
    mapElement.current?.dispatchEvent(new CustomEvent("landmark-search-result", { detail: { latitude: Number(result.lat), longitude: Number(result.lon) } }));
    setSearchQuery(result.display_name.split(",").slice(0, 3).join(","));
    setSearchResults([]);
    setSearchError("");
  };

  useEffect(() => {
    if (!mapElement.current) return;
    let disposed = false;
    let map: any;
    let resizeObserver: ResizeObserver | undefined;
    let resetPicker: (() => void) | undefined;
    let searchResultHandler: ((event: Event) => void) | undefined;
    let coverageCircle: any;
    let radiusInput: HTMLInputElement | null = null;
    let radiusHandler: (() => void) | undefined;
    import("leaflet").then((L) => {
      if (disposed || !mapElement.current) return;
      const startingPoint: [number, number] = hasInitialPin ? [Number(latitude), Number(longitude)] : [14.2456, 120.8786];
      map = L.map(mapElement.current, { scrollWheelZoom: true }).setView(startingPoint, hasInitialPin ? 16 : 10);
      L.tileLayer("https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png", { attribution: "&copy; OpenStreetMap contributors", maxZoom: 19 }).addTo(map);
      let pin: any;
      let connectorDrawing = false;
      let connectorDraft: [number, number][] = [];
      let savedConnectors: [number, number][][] = (Array.isArray(accessPaths) ? accessPaths : []).map((path: any) => Array.isArray(path) ? path.map((point: any) => [Number(point?.[0]), Number(point?.[1])] as [number, number]).filter((point: [number, number]) => point.every(Number.isFinite)) : []).filter((path: [number, number][]) => path.length >= 2);
      const connectorLayers: any[] = [];
      let draftLayer: any;
      const connectorStyle = { color: "#7c3aed", weight: 6, opacity: .9, lineCap: "round" as const, lineJoin: "round" as const };
      const renderConnectors = () => {
        connectorLayers.splice(0).forEach((layer) => layer.remove());
        savedConnectors.forEach((path) => connectorLayers.push(L.polyline(path, connectorStyle).addTo(map)));
        draftLayer?.remove();
        draftLayer = connectorDraft.length ? L.polyline(connectorDraft, { ...connectorStyle, dashArray: "8 7" }).addTo(map) : undefined;
        pin?.bringToFront();
      };
      const publishConnectors = (includeDraft = false) => {
        const paths = includeDraft && connectorDraft.length >= 2 ? [...savedConnectors, connectorDraft] : savedConnectors;
        setSerializedAccessPaths(JSON.stringify(paths));
        setConnectorMessage(`${paths.length} verified connector${paths.length === 1 ? "" : "s"}${connectorDrawing ? " · drawing in progress" : ""}.`);
      };
      if (hasInitialPin) pin = L.circleMarker(startingPoint, { radius: 9, color: "#ffffff", weight: 3, fillColor: "#d89b2b", fillOpacity: 1 }).addTo(map);
      renderConnectors();
      accessPathActions.current = {
        start: () => {
          connectorDrawing = true;
          connectorDraft = [];
          setDrawingConnector(true);
          setConnectorMessage("Click each road point in order. Finish after at least two points.");
          renderConnectors();
        },
        finish: () => {
          if (connectorDraft.length < 2) {
            setConnectorMessage("A connector needs at least two map points.");
            return;
          }
          savedConnectors = [...savedConnectors, connectorDraft];
          connectorDraft = [];
          connectorDrawing = false;
          setDrawingConnector(false);
          renderConnectors();
          publishConnectors();
        },
        undo: () => {
          if (!connectorDraft.length) return;
          connectorDraft = connectorDraft.slice(0, -1);
          renderConnectors();
          publishConnectors(true);
        },
        clear: () => {
          savedConnectors = [];
          connectorDraft = [];
          connectorDrawing = false;
          setDrawingConnector(false);
          renderConnectors();
          publishConnectors();
        },
      };
      const coverageRadiusMeters = () => Math.max(100, Number(radiusInput?.value || 2) * 1000);
      const drawCoverage = (point: [number, number], fit = false) => {
        if (!showCoverageRadius) return;
        if (coverageCircle) coverageCircle.setLatLng(point).setRadius(coverageRadiusMeters());
        else coverageCircle = L.circle(point, { radius: coverageRadiusMeters(), color: "#0b8060", weight: 2, opacity: .8, fillColor: "#39a982", fillOpacity: .16 }).addTo(map);
        coverageCircle.bringToBack();
        pin?.bringToFront();
        if (fit) map.fitBounds(coverageCircle.getBounds(), { padding: [28, 28] });
      };
      radiusInput = mapElement.current?.closest("form")?.querySelector<HTMLInputElement>('input[name="coverageRadiusKm"]') || null;
      if (hasInitialPin) window.setTimeout(() => drawCoverage(startingPoint, true), 0);
      radiusHandler = () => { if (pin) drawCoverage([pin.getLatLng().lat, pin.getLatLng().lng], true); };
      radiusInput?.addEventListener("input", radiusHandler);
      const placePin = (pinLatitude: number, pinLongitude: number, recenter = false) => {
        const point: [number, number] = [pinLatitude, pinLongitude];
        if (pin) pin.setLatLng(point);
        else pin = L.circleMarker(point, { radius: 9, color: "#ffffff", weight: 3, fillColor: "#d89b2b", fillOpacity: 1 }).addTo(map);
        drawCoverage(point, true);
        if (recenter) map.setView(point, 17);
        const form = mapElement.current?.closest("form") || mapElement.current?.closest("section")?.querySelector("form");
        const latitudeInput = form?.querySelector<HTMLInputElement>('input[name="latitude"]');
        const longitudeInput = form?.querySelector<HTMLInputElement>('input[name="longitude"]');
        const formattedLatitude = pinLatitude.toFixed(6);
        const formattedLongitude = pinLongitude.toFixed(6);
        if (latitudeInput) latitudeInput.value = formattedLatitude;
        if (longitudeInput) longitudeInput.value = formattedLongitude;
        setCoordinates(`${formattedLatitude}, ${formattedLongitude}`);
        // Terminal forms can use the same picker as landmarks. Suggest the
        // locality from the chosen pin, but keep the inputs ordinary/editable
        // so an admin can correct a boundary or local naming difference.
        const municipalityInput = form?.querySelector<HTMLInputElement>('input[name="municipality"]');
        const barangayInput = form?.querySelector<HTMLInputElement>('input[name="barangay"]');
        if (municipalityInput || barangayInput) {
          fetch(`https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat=${pinLatitude}&lon=${pinLongitude}&zoom=18&addressdetails=1`)
            .then((response) => response.ok ? response.json() : null)
            .then((result) => {
              const address = result?.address || {};
              const municipality = address.city || address.town || address.municipality || address.county || '';
              const barangay = address.village || address.suburb || address.neighbourhood || address.quarter || '';
              if (municipalityInput && municipality) municipalityInput.value = municipality;
              if (barangayInput && barangay) barangayInput.value = barangay;
            }).catch(() => { /* Pin coordinates remain usable if reverse lookup is unavailable. */ });
        }
      };
      searchResultHandler = (event: Event) => {
        const detail = (event as CustomEvent<{ latitude: number; longitude: number }>).detail;
        placePin(detail.latitude, detail.longitude, true);
      };
      mapElement.current.addEventListener("landmark-search-result", searchResultHandler);
      resizeObserver = new ResizeObserver(() => { if (mapElement.current?.offsetWidth) map.invalidateSize(); });
      resizeObserver.observe(mapElement.current);
      resetPicker = () => { if (pin) { pin.remove(); pin = undefined; } if (coverageCircle) { coverageCircle.remove(); coverageCircle = undefined; } savedConnectors = []; connectorDraft = []; connectorDrawing = false; setDrawingConnector(false); renderConnectors(); publishConnectors(); map.setView(startingPoint, hasInitialPin ? 16 : 10); setCoordinates(hasInitialPin ? `${Number(latitude).toFixed(6)}, ${Number(longitude).toFixed(6)}` : "Click the map to place the landmark pin."); setSearchQuery(""); setSearchResults([]); setSearchError(""); };
      window.addEventListener("landmark-form-reset", resetPicker);
      map.on("click", (event: any) => {
        if (enableAccessPathDrawing && connectorDrawing) {
          connectorDraft = [...connectorDraft, [event.latlng.lat, event.latlng.lng]];
          renderConnectors();
          publishConnectors(true);
          return;
        }
        placePin(event.latlng.lat, event.latlng.lng);
      });
      setTimeout(() => map?.invalidateSize(), 0);
    });
    return () => { disposed = true; accessPathActions.current = null; resizeObserver?.disconnect(); if (radiusHandler) radiusInput?.removeEventListener("input", radiusHandler); if (resetPicker) window.removeEventListener("landmark-form-reset", resetPicker); if (searchResultHandler) mapElement.current?.removeEventListener("landmark-search-result", searchResultHandler); map?.remove(); };
  }, [latitude, longitude, showCoverageRadius, enableAccessPathDrawing]);
  return <div className="landmark-map-picker"><div className="map-picker-heading"><div><strong>{label}</strong><span>{helper}</span></div><output>{coordinates}</output></div><div className="map-search"><div className="map-search-row"><input type="search" value={searchQuery} onChange={(event) => setSearchQuery(event.target.value)} onKeyDown={(event) => { if (event.key === "Enter") { event.preventDefault(); searchMap(); } }} placeholder="Search a landmark, street, or address" aria-label="Search for a location in Cavite" /><button type="button" onClick={searchMap} disabled={searching}>{searching ? "Searching…" : "Search"}</button></div>{searchError && <p className="map-search-message">{searchError}</p>}{searchResults.length > 0 && <div className="map-search-results" role="listbox" aria-label="Map search results">{searchResults.map((result) => <button type="button" role="option" key={result.place_id} onClick={() => selectSearchResult(result)}><strong>{result.display_name.split(",")[0]}</strong><span>{result.display_name.split(",").slice(1).join(",").trim()}</span></button>)}</div>}<small className="map-search-attribution">Search data © OpenStreetMap contributors</small></div>{enableAccessPathDrawing && <div className="tricycle-connector-tools"><div><strong>Verified road connectors</strong><span>Draw only real missing or disconnected streets.</span><small>{connectorMessage}</small></div><div><button type="button" className={drawingConnector ? "active" : ""} onClick={() => accessPathActions.current?.start()}>{drawingConnector ? "Restart connector" : "Draw missing road"}</button><button type="button" onClick={() => accessPathActions.current?.undo()} disabled={!drawingConnector}>Undo point</button><button type="button" className="primary" onClick={() => accessPathActions.current?.finish()} disabled={!drawingConnector}>Finish connector</button><button type="button" className="danger" onClick={() => accessPathActions.current?.clear()}>Clear connectors</button></div><input type="hidden" name="accessPaths" value={serializedAccessPaths} readOnly /></div>}<div ref={mapElement} className="landmark-map" aria-label="Interactive map for selecting the landmark location" /></div>;
}

type MapSearchResult = { place_id: number; lat: string; lon: string; display_name: string };

const landmarkCategories = [
  "Historical Site",
  "Heritage House",
  "Museum",
  "Monument / Memorial",
  "Church / Religious Site",
  "Plaza / Civic Space",
  "Park / Recreation",
  "Nature Attraction",
  "Beach / Coastal Attraction",
  "Cultural Site",
];

const caviteMunicipalities = [
  { name: "Alfonso", code: "042101000" }, { name: "Amadeo", code: "042102000" },
  { name: "Bacoor", code: "042103000" }, { name: "Carmona", code: "042104000" },
  { name: "Cavite City", code: "042105000" }, { name: "Dasmariñas", code: "042106000" },
  { name: "General Emilio Aguinaldo", code: "042107000" }, { name: "General Trias", code: "042108000" },
  { name: "Imus", code: "042109000" }, { name: "Indang", code: "042110000" },
  { name: "Kawit", code: "042111000" }, { name: "Magallanes", code: "042112000" },
  { name: "Maragondon", code: "042113000" }, { name: "Mendez", code: "042114000" },
  { name: "Naic", code: "042115000" }, { name: "Noveleta", code: "042116000" },
  { name: "Rosario", code: "042117000" }, { name: "Silang", code: "042118000" },
  { name: "Tagaytay", code: "042119000" }, { name: "Tanza", code: "042120000" },
  { name: "Ternate", code: "042121000" }, { name: "Trece Martires", code: "042122000" },
  { name: "General Mariano Alvarez", code: "042123000" },
];

const currentBacoorBarangays = [
  "Aniban 1", "Aniban 2", "Bayanan", "Dulong Bayan", "Habay I", "Habay II", "Kaingin Digman", "Ligas 1", "Ligas 2", "Mabolo", "Maliksi 1", "Maliksi 2", "Mambog 1", "Mambog 2", "Mambog 3", "Mambog 4", "Molino I", "Molino II", "Molino III", "Molino IV", "Molino V", "Molino VI", "Molino VII", "Niog", "P.F. Espiritu 1", "P.F. Espiritu 2", "P.F. Espiritu 3", "P.F. Espiritu 4", "P.F. Espiritu 5", "P.F. Espiritu 6", "Poblacion", "Queens Row Central", "Queens Row East", "Queens Row West", "Real", "Salinas I", "Salinas 2", "San Nicolas 1", "San Nicolas II", "San Nicolas III", "Sinbanali", "Talaba 1", "Talaba 2", "Talaba 3", "Zapote 1", "Zapote 2", "Zapote 3",
];

function normalizedMunicipality(value: string) {
  const simplified = value.trim().replace(/^City of /i, "").replace(/^Gen\. /i, "General ");
  return caviteMunicipalities.find((item) => item.name.toLowerCase() === simplified.toLowerCase())?.name || "";
}

function municipalityFromReverseGeocode(result: any) {
  const address = result?.address || {};
  const candidates = [address.city, address.town, address.municipality, address.county]
    .filter(Boolean)
    .map(String);

  for (const candidate of candidates) {
    const match = normalizedMunicipality(candidate);
    if (match) return match;
    const cleaned = candidate.trim().replace(/^City of /i, "");
    if (cleaned) return cleaned;
  }

  const displayParts = String(result?.display_name || "").split(",").map((part) => part.trim());
  for (const part of displayParts) {
    const match = normalizedMunicipality(part);
    if (match) return match;
  }
  return "";
}

const routeMunicipalitySuggestions = [
  ...caviteMunicipalities.map((item) => item.name),
  "Las Piñas",
  "Muntinlupa",
  "Parañaque",
  "Pasay",
  "San Pedro",
  "Biñan",
].sort();

function MunicipalityBarangayFields({ initialMunicipality = "", initialBarangay = "" }: { initialMunicipality?: string; initialBarangay?: string }) {
  const [municipality, setMunicipality] = useState(normalizedMunicipality(initialMunicipality));
  const [barangay, setBarangay] = useState(initialBarangay);
  const [barangays, setBarangays] = useState<string[]>([]);
  const [loading, setLoading] = useState(false);
  const [loadError, setLoadError] = useState("");

  useEffect(() => {
    const reset = () => { setMunicipality(""); setBarangay(""); setBarangays([]); setLoadError(""); };
    window.addEventListener("landmark-form-reset", reset);
    return () => window.removeEventListener("landmark-form-reset", reset);
  }, []);

  useEffect(() => {
    const selected = caviteMunicipalities.find((item) => item.name === municipality);
    if (!selected) { setBarangays([]); setLoading(false); return; }
    if (municipality === "Bacoor") {
      const values = initialBarangay && !currentBacoorBarangays.includes(initialBarangay) ? [initialBarangay, ...currentBacoorBarangays] : currentBacoorBarangays;
      setBarangays(values);
      setLoading(false);
      return;
    }
    const controller = new AbortController();
    setLoading(true);
    setLoadError("");
    fetch(`https://psgc.gitlab.io/api/cities-municipalities/${selected.code}/barangays.json`, { signal: controller.signal })
      .then((response) => { if (!response.ok) throw Error("Barangays could not be loaded."); return response.json(); })
      .then((items: Array<{ name?: string }>) => {
        const names = items.map((item) => String(item.name || "").trim()).filter(Boolean).sort((a, b) => a.localeCompare(b));
        setBarangays(initialBarangay && !names.includes(initialBarangay) ? [initialBarangay, ...names] : names);
      })
      .catch((error) => { if (error.name !== "AbortError") setLoadError("Could not load barangays. Please select the municipality again."); })
      .finally(() => setLoading(false));
    return () => controller.abort();
  }, [municipality, initialBarangay]);

  return <>
    <label className="landmark-municipality-field">Municipality or city<select name="municipality" value={municipality} onChange={(event) => { setMunicipality(event.target.value); setBarangay(""); }} required><option value="">Select municipality or city</option>{caviteMunicipalities.map((item) => <option key={item.code} value={item.name}>{item.name}</option>)}</select></label>
    <label className="landmark-barangay-field">Barangay<select name="barangay" value={barangay} onChange={(event) => setBarangay(event.target.value)} disabled={!municipality || loading} required><option value="">{loading ? "Loading barangays…" : municipality ? "Select barangay" : "Select a municipality first"}</option>{barangays.map((item) => <option key={item} value={item}>{item}</option>)}</select>{loadError && <small className="location-field-error">{loadError}</small>}</label>
  </>;
}

function LandmarkPhotoUploader({ initialImages = [] }: { initialImages?: string[] }) {
  const [images, setImages] = useState<string[]>(initialImages);
  const [uploading, setUploading] = useState(false);
  const [error, setError] = useState("");
  useEffect(() => { const reset = () => { setImages(initialImages); setError(""); }; window.addEventListener("landmark-form-reset", reset); return () => window.removeEventListener("landmark-form-reset", reset); }, []);
  const upload = async (event: ChangeEvent<HTMLInputElement>) => {
    const files = Array.from(event.target.files || []);
    event.target.value = "";
    if (!files.length) return;
    if (images.length + files.length > 5) { setError("You can add up to 5 photos per landmark."); return; }
    setUploading(true);
    setError("");
    try {
      const uploaded: string[] = [];
      for (const file of files) {
        const body = new FormData();
        body.append("file", file);
        const response = await fetch(`${API}/admin/places/upload-image`, { method: "POST", headers: { Authorization: `Bearer ${sessionStorage.getItem("admin_token") || ""}` }, body });
        const result = await response.json().catch(() => ({}));
        if (!response.ok) throw Error(result.message || "Photo upload failed.");
        uploaded.push(result.path);
      }
      setImages((current) => [...current, ...uploaded]);
    } catch (uploadError: any) { setError(uploadError.message); }
    finally { setUploading(false); }
  };
  return <div className="landmark-photo-field"><div className="photo-field-heading"><div><strong>Landmark photos</strong><span>Add up to 5 JPG, PNG, or WebP images. Maximum 5 MB each.</span></div><label className={`photo-upload-button${images.length >= 5 ? " disabled" : ""}`}>{uploading ? "Uploading…" : images.length >= 5 ? "5 photos added" : images.length ? "Add another" : "Choose photos"}<input type="file" accept="image/jpeg,image/png,image/webp" multiple onChange={upload} disabled={uploading || images.length >= 5} /></label></div><input type="hidden" name="images" value={JSON.stringify(images)} readOnly />{images.length > 0 && <div className="landmark-photo-grid">{images.map((image, index) => <figure key={image}><img src={image.startsWith("http") ? image : `${API}${image}`} alt={`Landmark preview ${index + 1}`} /><button type="button" aria-label={`Remove photo ${index + 1}`} onClick={() => setImages((current) => current.filter((_, itemIndex) => itemIndex !== index))}>Remove</button></figure>)}</div>}{!images.length && !uploading && <div className="photo-empty-state"><span>＋</span><p>No photos added yet.</p></div>}{error && <p className="photo-upload-error">{error}</p>}</div>;
}

function LandmarkFields({ fields, values }: { fields: string[]; values?: Record<string, any> }) {
  const categories = values?.category && !landmarkCategories.includes(values.category) ? [values.category, ...landmarkCategories] : landmarkCategories;
  return <>{fields.map((field) => field === "municipality" ? <MunicipalityBarangayFields key="location-fields" initialMunicipality={values?.municipality ?? ""} initialBarangay={values?.barangay ?? ""} /> : field === "barangay" ? null : <label key={field} className={field === "description" ? "landmark-description-field" : `landmark-${field}-field`}>{field === "category" ? "Place type" : field.replace(/([A-Z])/g, " $1").replace(/^./, (letter) => letter.toUpperCase())}{field === "description" ? <textarea name={field} defaultValue={values?.[field] ?? ""} placeholder="Describe what makes this place worth visiting" rows={4} required /> : field === "category" ? <select name={field} defaultValue={values?.[field] ?? "Historical Site"} required>{categories.map((item) => <option key={item} value={item}>{item}</option>)}</select> : <input name={field} defaultValue={values?.[field] ?? ""} placeholder={`Enter ${field.replace(/([A-Z])/g, " $1")}`} required />}</label>)}<LandmarkPhotoUploader initialImages={Array.isArray(values?.images) ? values.images : []} /></>;
}

const landmarkWizardSteps = ["Essential", "Visitor", "History", "Reminders", "Review"];

function LandmarkCreationWizard({ save }: { save: (event: FormEvent<HTMLFormElement>) => void }) {
  const [step, setStep] = useState(0);
  const [review, setReview] = useState<Record<string, any>>({});
  const [isAdmin, setIsAdmin] = useState(false);
  const formRef = useRef<HTMLFormElement>(null);
  const statusRef = useRef<HTMLInputElement>(null);
  useEffect(() => { setIsAdmin(sessionStorage.getItem("admin_role") === "admin"); const reset = () => { setStep(0); setReview({}); }; window.addEventListener("landmark-form-reset", reset); return () => window.removeEventListener("landmark-form-reset", reset); }, []);
  const capture = () => { if (!formRef.current) return {}; const values: Record<string, any> = Object.fromEntries(new FormData(formRef.current)); setReview(values); return values; };
  const next = () => {
    const panel = formRef.current?.querySelector<HTMLElement>(`[data-step="${step}"]`);
    const invalid = panel?.querySelector<HTMLInputElement | HTMLTextAreaElement | HTMLSelectElement>(":invalid");
    if (invalid) { invalid.reportValidity(); return; }
    capture();
    setStep((current) => Math.min(current + 1, landmarkWizardSteps.length - 1));
  };
  const submitAs = (status: string) => { if (!formRef.current || !statusRef.current) return; statusRef.current.value = status; formRef.current.requestSubmit(); };
  const reviewImages = (() => { try { return JSON.parse(review.images || "[]"); } catch { return []; } })();
  return <section className="card landmark-wizard-card"><ol className="landmark-wizard-steps">{landmarkWizardSteps.map((label, index) => <li key={label} className={index === step ? "active" : index < step ? "complete" : ""}><button type="button" disabled={index > step} onClick={() => setStep(index)}><span>{index < step ? "✓" : index + 1}</span>{label}</button></li>)}</ol><form ref={formRef} onSubmit={save} className="landmark-wizard-form"><input ref={statusRef} type="hidden" name="publicationStatus" defaultValue="draft" />
    <section className={step === 0 ? "wizard-panel active" : "wizard-panel"} data-step="0"><div className="wizard-panel-heading"><p className="eyebrow">STEP 1 OF 5</p><h2>Essential information</h2><p>Identify the landmark, complete its local address, add photos, and pin its exact location.</p></div><div className="wizard-essential-grid"><div className="wizard-fields"><label>Landmark name<input name="name" placeholder="Enter the official landmark name" required /></label><label>Place type<select name="category" defaultValue="Historical Site" required>{landmarkCategories.map((item) => <option key={item}>{item}</option>)}</select></label><label className="wide-field">Short summary<input name="shortSummary" maxLength={180} placeholder="A brief introduction shown in landmark cards" required /></label><label className="wide-field">Complete description<textarea name="description" rows={5} placeholder="Describe what visitors can see, experience, and learn" required /></label><label className="wide-field">Street address<input name="streetAddress" placeholder="House number, street, or road" required /></label><MunicipalityBarangayFields /><label>Latitude<input name="latitude" placeholder="Select a point on the map" required /></label><label>Longitude<input name="longitude" placeholder="Select a point on the map" required /></label><LandmarkPhotoUploader /></div><MapPicker /></div></section>
    <section className={step === 1 ? "wizard-panel active" : "wizard-panel"} data-step="1"><div className="wizard-panel-heading"><p className="eyebrow">STEP 2 OF 5</p><h2>Visitor information</h2><p>Add the practical details visitors should know before travelling.</p></div><div className="wizard-fields visitor-fields"><label className="wide-field">Opening days<input name="openingDays" placeholder="e.g. Tuesday to Sunday" /></label><label>Opening time<input name="openingTime" type="time" /></label><label>Closing time<input name="closingTime" type="time" /></label><label className="check-field"><input name="isAlwaysOpen" type="checkbox" value="true" /><span>Open 24 hours</span></label><label>Entrance fee<input name="entranceFee" placeholder="e.g. ₱50 per visitor" /></label><label className="check-field"><input name="isFreeEntrance" type="checkbox" value="true" /><span>Free entrance</span></label><label>Contact number<input name="contactNumber" type="tel" placeholder="Official contact number" /></label><label>Website or Facebook page<input name="websiteUrl" type="url" placeholder="https://" /></label><label>Estimated visit duration<input name="visitDuration" placeholder="e.g. 1–2 hours" /></label><label>Best time to visit<input name="bestTimeToVisit" placeholder="e.g. Weekday mornings" /></label><label>Current status<select name="operatingStatus" defaultValue="open"><option value="open">Open</option><option value="temporarily_closed">Temporarily closed</option><option value="under_maintenance">Under maintenance</option></select></label></div></section>
    <section className={step === 2 ? "wizard-panel active" : "wizard-panel"} data-step="2"><div className="wizard-panel-heading"><p className="eyebrow">STEP 3 OF 5</p><h2>Historical information</h2><p>Document why the landmark matters and where the information came from.</p></div><div className="wizard-fields history-fields"><label className="wide-field">Historical background<textarea name="historicalBackground" rows={6} placeholder="Tell the story of the landmark" /></label><label className="wide-field">Cultural significance<textarea name="culturalSignificance" rows={4} placeholder="Explain its importance to Cavite and the community" /></label><label>Year established<input name="yearEstablished" placeholder="e.g. 1845 or circa 1800s" /></label><label className="wide-field">Important people<textarea name="importantPeople" rows={3} placeholder="Enter one person per line" /></label><label className="wide-field">Important events<textarea name="importantEvents" rows={3} placeholder="Enter one event per line" /></label><label className="wide-field">Interesting facts<textarea name="interestingFacts" rows={3} placeholder="Enter one fact per line" /></label><label className="wide-field">Sources and references<textarea name="informationSources" rows={3} placeholder="Enter one book, archive, website, or reference per line" /></label></div></section>
    <section className={step === 3 ? "wizard-panel active" : "wizard-panel"} data-step="3"><div className="wizard-panel-heading"><p className="eyebrow">STEP 4 OF 5</p><h2>Visitor reminders</h2><p>Record practical rules and advice. Leave fields blank when they do not apply.</p></div><div className="wizard-fields reminder-fields"><label>Dress code<textarea name="dressCode" rows={3} placeholder="Appropriate clothing or footwear" /></label><label>Photography rules<textarea name="photographyRules" rows={3} placeholder="Where photos are allowed or restricted" /></label><label>Prohibited items<textarea name="prohibitedItems" rows={3} placeholder="Items visitors cannot bring" /></label><label>Pet policy<textarea name="petPolicy" rows={3} placeholder="Whether pets are allowed" /></label><label>Safety reminders<textarea name="safetyReminders" rows={3} placeholder="Hazards and safety precautions" /></label><label>Emergency contact<input name="emergencyContact" placeholder="Emergency number or office" /></label><label className="wide-field">General visitor tips<textarea name="visitorTips" rows={4} placeholder="Helpful advice for a comfortable visit" /></label></div></section>
    <section className={step === 4 ? "wizard-panel active" : "wizard-panel"} data-step="4"><div className="wizard-panel-heading"><p className="eyebrow">STEP 5 OF 5</p><h2>Review landmark</h2><p>Check the information before saving it to the landmark directory.</p></div><div className="landmark-review"><article className="review-hero">{reviewImages[0] ? <img src={reviewImages[0].startsWith("http") ? reviewImages[0] : `${API}${reviewImages[0]}`} alt="Landmark cover preview" /> : <div className="review-photo-placeholder">No cover photo</div>}<div><span>{review.category || "Historical Site"}</span><h3>{review.name || "Untitled landmark"}</h3><p>{[review.streetAddress, review.barangay && `Barangay ${review.barangay}`, review.municipality].filter(Boolean).join(", ")}</p></div></article><div className="review-grid"><article><strong>Visitor information</strong><p>{review.isAlwaysOpen ? "Open 24 hours" : [review.openingDays, review.openingTime && review.closingTime ? `${review.openingTime}–${review.closingTime}` : ""].filter(Boolean).join(" · ") || "Schedule not provided"}</p><p>{review.isFreeEntrance ? "Free entrance" : review.entranceFee || "Entrance fee not provided"}</p></article><article><strong>Historical information</strong><p>{review.historicalBackground || "Historical background not provided."}</p></article><article><strong>Visitor reminders</strong><p>{review.visitorTips || review.safetyReminders || "No special reminders provided."}</p></article><article><strong>Map coordinates</strong><p>{review.latitude || "—"}, {review.longitude || "—"}</p></article></div></div></section>
    <footer className="wizard-actions"><button type="button" className="secondary" onClick={() => setStep((current) => Math.max(0, current - 1))} disabled={step === 0}>← Previous</button>{step < 4 ? <button type="button" className="primary" onClick={next}>Continue →</button> : <div><button type="button" className="secondary" onClick={() => submitAs("draft")}>Save as draft</button><button type="button" className="secondary review-submit" onClick={() => submitAs("for_review")}>Submit for review</button>{isAdmin && <button type="button" className="primary" onClick={() => submitAs("published")}>Publish landmark</button>}</div>}</footer>
  </form></section>;
}

function LandmarkViewTabs() {
  return <section className="landmark-view-switch" aria-label="Landmark workspace views"><div className="landmark-segmented"><input type="radio" id="landmark-view-browse" name="landmark-view" defaultChecked /><label htmlFor="landmark-view-browse">Browse landmarks</label><input type="radio" id="landmark-view-add" name="landmark-view" /><label htmlFor="landmark-view-add">Add landmark</label></div><p className="browse-view-copy">Search saved landmarks, filter the directory, or update an existing place.</p><p className="add-view-copy">Create a destination, complete its local address, and pin its exact map location.</p></section>;
}

function Form({ title, subtitle, fields, save }: { title: string; subtitle: string; fields: string[]; save: (event: FormEvent<HTMLFormElement>) => void }) { const hasLocation = fields.includes("latitude") && fields.includes("longitude"); const isLandmark = title === "Add a landmark"; if (isLandmark) return <><LandmarkViewTabs /><LandmarkCreationWizard save={save} /></>; return <section className="card entry-card"><div className="section-heading"><div><p className="eyebrow">NEW RECORD</p><h2>{title}</h2><p>{subtitle}</p></div></div>{hasLocation && <MapPicker />}<form onSubmit={save}>{fields.map((field) => <label key={field}>{field.replace(/([A-Z])/g, " $1").replace(/^./, (letter) => letter.toUpperCase())}<input name={field} placeholder={`Enter ${field.replace(/([A-Z])/g, " $1")}`} required={!field.endsWith("Id") && field !== "notes"} /></label>)}<button className="primary form-submit">Save record →</button></form></section>; }
function LandmarkEditForm({ landmark, onCancel, onSaved }: { landmark: any; onCancel: () => void; onSaved: (landmark: any) => void }) {
  const [notice, setNotice] = useState("");
  const [isAdmin, setIsAdmin] = useState(false);
  useEffect(() => setIsAdmin(sessionStorage.getItem("admin_role") === "admin"), []);
  const update = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    setNotice("");
    const response = await fetch(`${API}/admin/places/${landmark.id}`, {
      method: "PATCH",
      headers: { "Content-Type": "application/json", Authorization: `Bearer ${sessionStorage.getItem("admin_token") || ""}` },
      body: JSON.stringify((() => { const values: Record<string, any> = Object.fromEntries(new FormData(event.currentTarget)); values.images = JSON.parse(values.images || "[]"); return values; })()),
    });
    const body = await response.json().catch(() => ({}));
    if (!response.ok) { setNotice(body.message || "Could not update this landmark."); return; }
    onSaved(body);
  };
  const changeStatus = async (publicationStatus: string) => {
    setNotice("");
    const response = await fetch(`${API}/admin/places/${landmark.id}`, { method: "PATCH", headers: { "Content-Type": "application/json", Authorization: `Bearer ${sessionStorage.getItem("admin_token") || ""}` }, body: JSON.stringify({ publicationStatus }) });
    const body = await response.json().catch(() => ({}));
    if (!response.ok) { setNotice(body.message || "Could not update the publication status."); return; }
    onSaved(body);
  };
  const fields = ["name", "shortSummary", "streetAddress", "municipality", "barangay", "description", "category", "latitude", "longitude"];
  return <section className="card entry-card landmark-edit-card"><div className="section-heading"><div><p className="eyebrow">EDIT LANDMARK</p><h2>Update {landmark.name}</h2><p>Review its essential information, photos, and map pin.</p></div><button type="button" className="secondary" onClick={onCancel}>Cancel editing</button></div><MapPicker latitude={landmark.latitude} longitude={landmark.longitude} /><form onSubmit={update}><LandmarkFields fields={fields} values={landmark} /><button className="primary form-submit">Save changes →</button></form><div className="modal-publication-actions"><div><span>Workflow status</span><strong>{String(landmark.publicationStatus || "published").replace("_", " ")}</strong></div>{!isAdmin && landmark.publicationStatus !== "for_review" && landmark.publicationStatus !== "published" && <button type="button" className="secondary" onClick={() => changeStatus("for_review")}>Submit for review</button>}{isAdmin && landmark.publicationStatus !== "published" && <button type="button" className="primary" onClick={() => changeStatus("published")}>Publish landmark</button>}{isAdmin && landmark.publicationStatus === "published" && <button type="button" className="secondary archive-button" onClick={() => changeStatus("archived")}>Archive landmark</button>}</div>{notice && <p className="form-message">{notice}</p>}</section>;
}

function Table({ title, rows, fields }: { title: string; rows: any[]; fields: string[] }) {
  const canEditLandmarks = title === "Saved landmarks";
  const [editing, setEditing] = useState<any | null>(null);
  const [displayRows, setDisplayRows] = useState(rows);
  const [notice, setNotice] = useState("");
  const [query, setQuery] = useState("");
  const [municipality, setMunicipality] = useState("all");
  const [category, setCategory] = useState("all");
  const [publication, setPublication] = useState("all");
  const [isAdmin, setIsAdmin] = useState(false);
  useEffect(() => setDisplayRows(rows), [rows]);
  useEffect(() => setIsAdmin(sessionStorage.getItem("admin_role") === "admin"), []);
  useEffect(() => {
    if (!editing) return;
    const previousOverflow = document.body.style.overflow;
    const closeOnEscape = (event: KeyboardEvent) => { if (event.key === "Escape") setEditing(null); };
    document.body.style.overflow = "hidden";
    window.addEventListener("keydown", closeOnEscape);
    return () => { document.body.style.overflow = previousOverflow; window.removeEventListener("keydown", closeOnEscape); };
  }, [editing]);
  const municipalities = [...new Set(displayRows.map((row) => String(row.municipality || "").trim()).filter(Boolean))].sort();
  const categories = [...new Set(displayRows.map((row) => String(row.category || "").trim()).filter(Boolean))].sort();
  const visibleRows = canEditLandmarks ? displayRows.filter((row) => {
    const searchText = `${row.name || ""} ${row.municipality || ""} ${row.barangay || ""} ${row.category || ""}`.toLowerCase();
    return searchText.includes(query.trim().toLowerCase())
      && (municipality === "all" || row.municipality === municipality)
      && (category === "all" || row.category === category)
      && (publication === "all" || (row.publicationStatus || "published") === publication);
  }) : displayRows;
  const clearFilters = () => { setQuery(""); setMunicipality("all"); setCategory("all"); setPublication("all"); };
  const editLandmark = (row: any) => {
    setNotice("");
    setEditing(row);
  };
  const saved = (updated: any) => {
    const original = rows.find((row) => row.id === updated.id);
    if (original) Object.assign(original, updated);
    setDisplayRows((current) => current.map((row) => row.id === updated.id ? updated : row));
    setEditing(null);
    setNotice("Landmark and pin location updated successfully.");
  };
  const deleted = (id: string) => {
    const originalIndex = rows.findIndex((row) => row.id === id);
    if (originalIndex >= 0) rows.splice(originalIndex, 1);
    setDisplayRows((current) => current.filter((row) => row.id !== id));
    setEditing(null);
    setNotice("Landmark deleted successfully.");
  };
  const deleteLandmark = async (row: any) => {
    if (!window.confirm(`Remove ${row.name}? If it is used by saved trips, badges, or rewards, it will be archived to preserve user history.`)) return;
    setNotice("");
    const response = await fetch(`${API}/admin/places/${row.id}`, { method: "DELETE", headers: { Authorization: `Bearer ${sessionStorage.getItem("admin_token") || ""}` } });
    const body = await response.json().catch(() => ({}));
    if (!response.ok) { setNotice(body.message || "Could not delete this landmark. It may still be used by trips, badges, or rewards."); return; }
    if (body.archived) {
      const archived = body.place || { ...row, publicationStatus: "archived" };
      const original = rows.find((item) => item.id === row.id);
      if (original) Object.assign(original, archived);
      setDisplayRows((current) => current.map((item) => item.id === row.id ? { ...item, ...archived } : item));
      const usage = body.usage || {};
      const references = Number(usage.trips || 0) + Number(usage.earnedBy || 0) + Number(usage.offers || 0);
      setNotice(`${row.name} was archived because ${references} related ${references === 1 ? "record uses" : "records use"} it. It is no longer shown in the mobile app.`);
      return;
    }
    deleted(row.id);
  };
  const coordinate = (value: any) => Number.isFinite(Number(value)) ? Number(value).toFixed(6) : "—";
  const table = canEditLandmarks ? <table className="landmark-directory-table"><thead><tr><th>Landmark</th><th>Location</th><th>Place type</th><th>Status</th><th>Coordinates</th><th>Actions</th></tr></thead><tbody>{visibleRows.length ? visibleRows.map((row) => <tr key={row.id}><td className="landmark-name-cell"><strong>{row.name}</strong><small>{row.shortSummary || "No summary provided"}</small></td><td className="landmark-location-cell"><strong>{row.municipality || "Cavite"}</strong><small>{row.barangay ? `Barangay ${row.barangay}` : "Barangay not set"}</small></td><td><span className="landmark-category-badge">{row.category || "Historical Site"}</span></td><td><span className={`publication-status-badge ${row.publicationStatus || "published"}`}>{String(row.publicationStatus || "published").replace("_", " ")}</span></td><td className="landmark-coordinates"><span>{coordinate(row.latitude)}</span><span>{coordinate(row.longitude)}</span></td><td><div className="landmark-row-actions"><button type="button" className="table-edit-button" onClick={() => editLandmark(row)}>Edit</button>{isAdmin && <button type="button" className="table-delete-button" onClick={() => deleteLandmark(row)}>Delete</button>}</div></td></tr>) : <tr><td className="empty" colSpan={6}>{displayRows.length ? "No landmarks match your search and filters." : "No records yet. Add your first one above."}</td></tr>}</tbody></table> : <table><thead><tr>{fields.map((field) => <th key={field}>{field.replace(/([A-Z])/g, " $1")}</th>)}</tr></thead><tbody>{visibleRows.length ? visibleRows.map((row) => <tr key={row.id}>{fields.map((field) => <td key={field}>{String(row[field] ?? "—")}</td>)}</tr>) : <tr><td className="empty" colSpan={fields.length}>No records yet. Add your first one above.</td></tr>}</tbody></table>;
  return <>{editing && <div className="landmark-modal-backdrop" role="dialog" aria-modal="true" aria-label={`Edit ${editing.name}`} onMouseDown={(event) => { if (event.target === event.currentTarget) setEditing(null); }}><LandmarkEditForm key={editing.id} landmark={editing} onCancel={() => setEditing(null)} onSaved={saved} /></div>}<section className="card table-card landmark-directory-card"><div className="section-heading"><div><p className="eyebrow">LANDMARK DIRECTORY</p><h2>{title}</h2><p>Find a destination quickly, then open it to update its details or map pin.</p></div><span className="record-count">{canEditLandmarks ? `${visibleRows.length} of ${displayRows.length}` : `${displayRows.length} ${displayRows.length === 1 ? "record" : "records"}`}</span></div>{notice && <p className="form-message success-message">{notice}</p>}{canEditLandmarks && <div className="landmark-tools"><label className="landmark-search"><span>Search landmarks</span><input type="search" value={query} onChange={(event) => setQuery(event.target.value)} placeholder="Name, barangay, municipality, or category" /></label><label><span>Municipality</span><select value={municipality} onChange={(event) => setMunicipality(event.target.value)}><option value="all">All municipalities</option>{municipalities.map((item) => <option key={item} value={item}>{item}</option>)}</select></label><label><span>Category</span><select value={category} onChange={(event) => setCategory(event.target.value)}><option value="all">All categories</option>{categories.map((item) => <option key={item} value={item}>{item}</option>)}</select></label><label><span>Workflow</span><select value={publication} onChange={(event) => setPublication(event.target.value)}><option value="all">All statuses</option><option value="draft">Draft</option><option value="for_review">For review</option><option value="published">Published</option><option value="archived">Archived</option></select></label><button type="button" className="clear-filters" onClick={clearFilters} disabled={!query && municipality === "all" && category === "all" && publication === "all"}>Clear</button></div>}<div className="scroll">{table}</div></section></>;
}
function InvitePanel({ api }: { api: (path: string, opts?: RequestInit) => Promise<any> }) { const [link,setLink]=useState(""); const [notice,setNotice]=useState(""); const create=async(e:FormEvent<HTMLFormElement>)=>{e.preventDefault(); const form=e.currentTarget; try{const r=await api("/admin/invites",{method:"POST",body:JSON.stringify(Object.fromEntries(new FormData(form)))});setLink(r.inviteUrl);form.reset();setNotice("Invitation email sent.")}catch(x:any){setNotice(x.message)}}; return <section className="card entry-card"><p className="eyebrow">TEAM ACCESS</p><h2>Invite an editor or admin</h2><p>Create a secure one-time link. The recipient will set their own password.</p><form onSubmit={create}><label>Name<input name="name" placeholder="Optional"/></label><label>Email<input name="email" type="email" required placeholder="name@example.com"/></label><label>Role<select name="role" defaultValue="editor"><option value="editor">Editor</option><option value="admin">Admin</option></select></label><button className="primary form-submit">Create invite</button></form>{link&&<p className="form-message">Invitation link: {link}<button className="link-button" type="button" onClick={()=>navigator.clipboard.writeText(link)}>Copy link</button></p>}{notice&&<p className="form-message">{notice}</p>}</section>}
function Users({ rows, api, reload }: { rows: any[]; api: (path: string, opts?: RequestInit) => Promise<any>; reload: () => void }) {
  const [query, setQuery] = useState("");
  const [roleFilter, setRoleFilter] = useState("all");
  const [statusFilter, setStatusFilter] = useState("all");
  const change = async (id: string, role: string) => { await api(`/admin/users/${id}`, { method: "PATCH", body: JSON.stringify({ role }) }); reload(); };
  const changeStatus = async (id: string, isActive: boolean) => { await api(`/admin/users/${id}`, { method: "PATCH", body: JSON.stringify({ isActive }) }); reload(); };
  const currentUserId = typeof window === "undefined" ? "" : sessionStorage.getItem("admin_user_id") || "";
  const filtered = rows.filter((row) => {
    const text = `${row.name || ""} ${row.email || ""}`.toLowerCase();
    const matchesQuery = text.includes(query.trim().toLowerCase());
    const matchesRole = roleFilter === "all" || row.role === roleFilter;
    const matchesStatus = statusFilter === "all" || (statusFilter === "active" ? row.isActive : !row.isActive);
    return matchesQuery && matchesRole && matchesStatus;
  });
  const clear = () => { setQuery(""); setRoleFilter("all"); setStatusFilter("all"); };
  return <><InvitePanel api={api}/><section className="card table-card accounts-table"><div className="section-heading"><div><p className="eyebrow">ACCESS CONTROL</p><h2>Accounts</h2><p>Search members and manage portal permissions.</p></div><span className="record-count">{filtered.length} of {rows.length}</span></div><div className="account-tools"><label className="account-search"><span>Search</span><input type="search" value={query} onChange={(event) => setQuery(event.target.value)} placeholder="Search name or email" /></label><label><span>Role</span><select value={roleFilter} onChange={(event) => setRoleFilter(event.target.value)}><option value="all">All roles</option><option value="user">Users</option><option value="editor">Editors</option><option value="admin">Admins</option></select></label><label><span>Status</span><select value={statusFilter} onChange={(event) => setStatusFilter(event.target.value)}><option value="all">All statuses</option><option value="active">Active</option><option value="disabled">Disabled</option></select></label><button type="button" className="clear-filters" onClick={clear} disabled={!query && roleFilter === "all" && statusFilter === "all"}>Clear</button></div><div className="scroll"><table><thead><tr><th>Member</th><th>Role</th><th>Access</th></tr></thead><tbody>{filtered.length ? filtered.map((row) => { const isCurrentUser = row.id === currentUserId; return <tr key={row.id}><td><div className="person"><span>{(row.name || row.email || "?").slice(0,1).toUpperCase()}</span><div><strong>{row.name || "Unnamed explorer"}{isCurrentUser && <em className="you-badge">You</em>}</strong><small>{row.email}</small></div></div></td><td><select value={row.role} disabled={isCurrentUser} title={isCurrentUser ? "You cannot change your own role" : "Change account role"} onChange={(event) => change(row.id,event.target.value)}><option value="user">User</option><option value="editor">Editor</option><option value="admin">Admin</option></select></td><td><select className={row.isActive ? "status-select active-status" : "status-select disabled-status"} value={row.isActive ? "active" : "disabled"} disabled={isCurrentUser} title={isCurrentUser ? "You cannot disable your own account" : "Change account access"} onChange={(event) => changeStatus(row.id, event.target.value === "active")}><option value="active">Active</option><option value="disabled">Disabled</option></select></td></tr>; }) : <tr><td className="empty" colSpan={3}>No accounts match your search and filters.</td></tr>}</tbody></table></div></section></>;
}
