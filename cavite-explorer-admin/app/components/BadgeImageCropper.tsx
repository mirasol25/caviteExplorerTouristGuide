"use client";

import { PointerEvent as ReactPointerEvent, useEffect, useMemo, useRef, useState } from "react";

const FRAME_SIZE = 320;
const OUTPUT_SIZE = 900;

type Props = {
  file: File;
  onCancel: () => void;
  onCropped: (blob: Blob) => void;
};

export default function BadgeImageCropper({ file, onCancel, onCropped }: Props) {
  const imageRef = useRef<HTMLImageElement>(null);
  const dragRef = useRef({ pointerId: -1, x: 0, y: 0, startX: 0, startY: 0 });
  const [imageSize, setImageSize] = useState({ width: 1, height: 1 });
  const [zoom, setZoom] = useState(1);
  const [offset, setOffset] = useState({ x: 0, y: 0 });
  const [saving, setSaving] = useState(false);
  const imageUrl = useMemo(() => URL.createObjectURL(file), [file]);

  useEffect(() => () => URL.revokeObjectURL(imageUrl), [imageUrl]);
  useEffect(() => {
    const close = (event: KeyboardEvent) => { if (event.key === "Escape") onCancel(); };
    window.addEventListener("keydown", close);
    return () => window.removeEventListener("keydown", close);
  }, [onCancel]);

  const baseScale = Math.max(FRAME_SIZE / imageSize.width, FRAME_SIZE / imageSize.height);
  const renderedWidth = imageSize.width * baseScale * zoom;
  const renderedHeight = imageSize.height * baseScale * zoom;
  const clamp = (next: { x: number; y: number }) => ({
    x: Math.max(-(renderedWidth - FRAME_SIZE) / 2, Math.min((renderedWidth - FRAME_SIZE) / 2, next.x)),
    y: Math.max(-(renderedHeight - FRAME_SIZE) / 2, Math.min((renderedHeight - FRAME_SIZE) / 2, next.y)),
  });

  const startDrag = (event: ReactPointerEvent<HTMLDivElement>) => {
    event.currentTarget.setPointerCapture(event.pointerId);
    dragRef.current = { pointerId: event.pointerId, x: event.clientX, y: event.clientY, startX: offset.x, startY: offset.y };
  };
  const moveDrag = (event: ReactPointerEvent<HTMLDivElement>) => {
    if (dragRef.current.pointerId !== event.pointerId) return;
    setOffset(clamp({ x: dragRef.current.startX + event.clientX - dragRef.current.x, y: dragRef.current.startY + event.clientY - dragRef.current.y }));
  };
  const endDrag = (event: ReactPointerEvent<HTMLDivElement>) => {
    if (dragRef.current.pointerId === event.pointerId) dragRef.current.pointerId = -1;
  };
  const changeZoom = (value: number) => {
    const nextZoom = Math.max(1, Math.min(3, value));
    const ratio = nextZoom / zoom;
    const nextWidth = imageSize.width * baseScale * nextZoom;
    const nextHeight = imageSize.height * baseScale * nextZoom;
    setZoom(nextZoom);
    setOffset({
      x: Math.max(-(nextWidth - FRAME_SIZE) / 2, Math.min((nextWidth - FRAME_SIZE) / 2, offset.x * ratio)),
      y: Math.max(-(nextHeight - FRAME_SIZE) / 2, Math.min((nextHeight - FRAME_SIZE) / 2, offset.y * ratio)),
    });
  };

  const crop = async () => {
    const image = imageRef.current;
    if (!image) return;
    setSaving(true);
    const canvas = document.createElement("canvas");
    canvas.width = OUTPUT_SIZE;
    canvas.height = OUTPUT_SIZE;
    const context = canvas.getContext("2d");
    if (!context) { setSaving(false); return; }
    const imageLeft = (FRAME_SIZE - renderedWidth) / 2 + offset.x;
    const imageTop = (FRAME_SIZE - renderedHeight) / 2 + offset.y;
    const sourceX = Math.max(0, (-imageLeft / renderedWidth) * imageSize.width);
    const sourceY = Math.max(0, (-imageTop / renderedHeight) * imageSize.height);
    const sourceWidth = Math.min(imageSize.width - sourceX, (FRAME_SIZE / renderedWidth) * imageSize.width);
    const sourceHeight = Math.min(imageSize.height - sourceY, (FRAME_SIZE / renderedHeight) * imageSize.height);
    context.drawImage(image, sourceX, sourceY, sourceWidth, sourceHeight, 0, 0, OUTPUT_SIZE, OUTPUT_SIZE);
    canvas.toBlob((blob) => {
      setSaving(false);
      if (blob) onCropped(blob);
    }, "image/jpeg", .92);
  };

  return <div className="badge-crop-backdrop" role="dialog" aria-modal="true" aria-label="Crop badge image" onMouseDown={(event) => { if (event.target === event.currentTarget) onCancel(); }}>
    <section className="badge-crop-modal">
      <header><div><small>BADGE ARTWORK</small><h2>Crop your badge image</h2><p>Drag the image and adjust the zoom. The circle shows how it will appear in the app.</p></div><button type="button" onClick={onCancel} aria-label="Close crop editor">×</button></header>
      <div className="badge-crop-stage" onPointerDown={startDrag} onPointerMove={moveDrag} onPointerUp={endDrag} onPointerCancel={endDrag}>
        <img ref={imageRef} src={imageUrl} alt="Badge crop preview" draggable={false} onLoad={(event) => { setImageSize({ width: event.currentTarget.naturalWidth, height: event.currentTarget.naturalHeight }); setOffset({ x: 0, y: 0 }); }} style={{ width: renderedWidth, height: renderedHeight, left: (FRAME_SIZE - renderedWidth) / 2 + offset.x, top: (FRAME_SIZE - renderedHeight) / 2 + offset.y }} />
        <div className="badge-crop-mask" />
      </div>
      <label className="badge-zoom-control"><span>Zoom</span><input type="range" min="1" max="3" step="0.01" value={zoom} onChange={(event) => changeZoom(Number(event.target.value))} /><strong>{Math.round(zoom * 100)}%</strong></label>
      <footer><button type="button" className="secondary" onClick={onCancel}>Cancel</button><button type="button" className="primary" onClick={crop} disabled={saving}>{saving ? "Preparing…" : "Use cropped image"}</button></footer>
    </section>
  </div>;
}
