# Low-cost 3D asset & engine audit

Checked: 2026-11-20. Requirement: **不付费、低成本运营 — no paid production subscriptions.** Commercial targets: Android, iOS and Web.

## Recommendation

Use **Blender modeling → Rigify → hand-keyed animation → glTF 2.0 GLB** as the dependable $0 production path. Local AI reconstruction is an optional accelerator when suitable hardware already exists. Choose **CHR_Abram + PRP_AmphoraCluster** as the two production pilots; model **BLD_MainTent** separately for the Godot test.

**Godot 4 is viable at $0 engine cost.** Preserve the existing game and validate a tiny Android slice before considering migration.

The approved camp-scene-mobile.png and abram-turnaround-4view.png remain the visual authority. This report supersedes the paid Tripo/Auto-Rig Pro assumptions and pending-image-review status in [ASSET_BREAKDOWN.md](ASSET_BREAKDOWN.md), which remains unchanged. Art approval does not itself establish input-image usage rights.

## Image-to-3D alternatives

“Commercial-safe” means the documented license permits the intended use, conditional on input rights and dependencies. A permissive model license is not an IP warranty for every generated mesh. Archive code commits, weight revisions and their respective licenses; cloud service terms are separate.

| Tool | License and real operating cost | Project verdict |
|---|---|---|
| **Microsoft TRELLIS**, original image-large | Official repository says models and most code are MIT; audit dependency exceptions. Reference setup: Linux and NVIDIA GPU with at least 16 GB VRAM. Windows/WSL adds setup work. [1] | Best optional local textured draft on suitable existing hardware. Export a mesh rather than Gaussian splats. Still requires topology, silhouette and texture cleanup. |
| **TripoSR** | MIT explicitly includes source and pretrained models; default single-image processing uses about 6 GB VRAM. [2] | Lighter local fallback. Expect weak unseen surfaces and clothing detail. This local release is distinct from paid Tripo SaaS. |
| **TripoSG** | MIT repository and official weights. Repository specifies CUDA GPU with at least 8 GB; model card says >8 GB. [3] | Useful shape-generation candidate; do not assume a finished texture pipeline. More setup than manually modeling these simple props. |
| **InstantMesh** | Apache-2.0 repository and official weights. Check Zero123++ and other downloaded dependencies separately. [4] | Permissive alternative; synthesized multi-view consistency and CUDA setup remain costs. No reason to install every model for two pilots. |
| **Tencent Hunyuan3D 2.0 / 2.1** | Each has a custom Tencent Hunyuan 3D Community License, **not MIT/Apache**. Conditional commercial use; EU, UK and South Korea are excluded territories, including output use/display under §5(c). §4 tests >1M MAU across the licensee's products/services in the preceding month **at the model version's release date**. It is not a generic future revenue cap. Notices, acceptable-use and other-model-improvement restrictions also apply. [5] | **Exclude from globally released assets.** Being below 1M users does not remove territorial restrictions. Older non-commercial headers/versions also exist: check exact code and weights, not tutorials. |
| **Meshy Free** | Outputs use **CC BY 4.0**, which permits commercial use with attribution. Free-plan assets are public rather than privately owned as on paid plans; credits/download entitlements can change. [6] | Conditional option, not the private baseline. Keep provider/creator credit, asset URL, license link and modification notice. CC BY is **not** non-commercial. Do not upload confidential references or assume later payment changes an earlier asset license. |
| **Rodin / Hyper3D Free** | Terms §6.2(b) broadly permit Rodin output use, but §2 ties commercial export to subscription plan. Free export entitlement needs asset-specific verification. **ChatAvatar** has a separate personal/non-commercial default grant and purchased commercial license. [7] | **Not cleared for this baseline** because free-plan commercial/export wording is insufficiently unambiguous. Do not incorrectly label all Rodin output NC. Check actual private/public settings before uploading. |

Free demos are experiments, not a production guarantee: quotas, queues, uptime, privacy and licensing are independent checks. Local processing still consumes electricity, disk and labor. Without an appropriate GPU, use Blender manually; this recommendation assumes no GPU purchase or paid compute.

## Rigging and animation without Auto-Rig Pro

| Tool | Commercial status | Practical caveats |
|---|---|---|
| **Blender Rigify — recommended** | Free official/bundled rigging tool; enable/install for the pinned Blender version. GPL applies to the software, not original artwork exported as data. Original meshes, rigs and GLB animations can ship commercially without tool royalties. [8] | Fit metarig, generate controls, bind and repair weights. Bake actions to a minimal deform skeleton. Exclude control widgets and scripts from GLB; redistribution of tool scripts is a separate GPL issue. |
| **Reallusion AccuRIG Free** | Free desktop humanoid auto-rigging with standard exports. However, current general Software EULA §2.1 phrases its export grant around purchased perpetual/active subscription licenses. This audit did not establish an unambiguous free-version commercial grant. [9] | Optional candidate pending the exact installed free EULA or vendor clarification; **not the cleared default**. Own mesh → FBX → Blender → baked GLB. Free rigging does not license ActorCore characters/motions or paid/trial content. |
| **Mixamo** | Adobe FAQ explicitly permits royalty-free commercial characters/animations with a free Adobe ID; no Creative Cloud subscription. [10] | FAQ excludes China-country-code accounts and Enterprise/Federated IDs. Do not depend on access here. Humanoid-only; robes, fused limbs, beard/cloak and staff can break auto-rigging. Embed content in the game; do not redistribute standalone character/motion libraries. Cloud upload and Adobe content terms still apply. |

Rigify provides **$0 commercial tool/output use**, not “100% rights guaranteed” for arbitrary imported content. Hand-keying two short clips avoids account, upload and animation-library dependencies entirely.

## Exact $0 pilot pipeline

1. **Provenance:** preserve both approved PNGs unchanged. Record input rights, tool/model revision, license URL/date, settings, edits, reviewer and final SHA-256 using the existing register fields. Keep working files local. No completed clearance record is implied by this audit.
2. **CHR_Abram mesh:** model an original low-poly A-pose character in Blender using the four views. Optional accelerator: one isolated front view → local TRELLIS; other views guide manual correction. Do not feed the four-panel sheet as one single-image object. Limit AI retries to two drafts, then model manually. Separate limbs and staff; preserve approved proportions, beard, robe and colors. Retopologize shoulders, knees and robe hem. Target **4,500–5,500 triangles**, height **1.55 m**, proposed one **1024²** atlas.
3. **Rig/animation:** Rigify controls → weight-paint robe/shoulders → hand-key 2–3 s idle and 1 s in-place walk → bake at 30 fps to approximately **28–32 deform bones**, maximum four influences/vertex. Disable unnecessary finger/twist chains for this slice; test deformation before reducing bones. Gameplay moves the root; avoid double root motion. Staff uses a separate hand attachment. Add gestures after the pilot passes.
4. **PRP_AmphoraCluster, second pilot:** revolve an original vessel profile in Blender, add simple handles and duplicate with variation. Share a hand-painted clay atlas; **≤600 triangles** for the cluster, proposed **512²** atlas. No rig. This is more predictable than reconstructing overlapping pots from a camp scene.
5. **BLD_MainTent, additional validation asset:** poles + shaped cloth planes + simple ropes, locally painted cloth/wood. Target **≤2,800 triangles**, **1024²** atlas, **4.2 × 3.2 × 2.5 m**. Match the approved dark goat-hair roof and six-pole silhouette. Separate simple collision; no cloth simulation or rig. Do not generate the whole camp as one fused mesh.
6. **Export:** retain editable .blend files; apply transforms, meter scale, foot pivot and normals. Export Y-up glTF 2.0 GLB with meshes, skin, baked actions and ordinary PBR textures. Verify facing in each engine: Godot conventions differ from the register's +Z-forward convention. Use rough matte materials and opaque surfaces where possible. Start with ordinary PNG/JPEG textures; do not assume compressed extensions behave identically across engines.
7. **Acceptance:** import identical GLBs into both viewers. Check approved 35–45° silhouette, back/side consistency, scale, seams, clip loops and robe deformation. Record triangles, materials, bones and bytes. Follow slice limits **<150 draw calls and <48 MB resident GPU textures (aim 32 MB)**. Triangle count alone does not prove mobile performance.

Cash budget: **$0 software, subscriptions and asset purchases on existing hardware**. Planning estimates, not measured production times: Abram 1–3 working days, pots 1–2 hours, tent 2–4 hours; unfamiliar modeling/retopology may take longer. Labor is the main tradeoff.

## Godot 4 versus the current stack

Repository evidence: package.json has React 19, Three.js 0.181, React Three Fiber 9, Capacitor 8 and Vite 6; native Android/iOS folders exist. README and docs/TECH.md describe gameplay, JSON saves and 14 GLB samples, but no physical-device performance result. docs/ENGINE_REVIEW.md already favors an isolated engine test.

| Concern | Godot 4 | Current Three.js + React + Capacitor |
|---|---|---|
| License | MIT, no royalties, seat subscription or revenue threshold. Retain engine/third-party notices. The acquired MIT version remains usable without payment; future releases are separate choices. [11] | Also no engine subscription required. Cost alone does not force migration; review dependencies/plugins/assets normally. |
| Workflow gains | Native GLB import, scene editor, Skeleton3D, AnimationPlayer/AnimationTree, NavigationServer3D/NavigationAgent3D and physics. Navigation still needs a valid navmesh and movement code. [12] | GLB already works; more scene authoring, navigation and animation orchestration must be implemented or integrated. |
| Renderer | **Mobile, Forward+ and Compatibility are three distinct renderers.** Mobile targets modern mobile GPUs; Forward+ adds higher-end features/cost; Compatibility serves broader low-end hardware and WebGL2 Web exports. [13] | Current WebGL/WebView route offers shared Web deployment. Capacitor packaging does not remove WebView overhead. |
| Android/iOS | Native engine runtime; Android requires SDK/JDK/export templates, debug APK and release-signed AAB/Gradle. iOS requires macOS/Xcode, provisioning and signing. [14] | Existing build → cap sync → Android Studio/Xcode workflow; native integrations have a starting point. Both require release preparation. |
| Web | WASM engine + project data add startup/download overhead; measure compressed bytes rather than quoting a universal MB size. Since 4.3, single-thread export avoids mandatory SharedArrayBuffer. Threaded builds need secure context and cross-origin isolation via COOP/COEP; third-party resources must cooperate. Test Safari/iOS. Use GDScript for the slice; Godot 4 C# Web export is not the baseline. [15] | No added Godot WASM runtime; React remains convenient for UI. Existing documented bundle size is historical, not a new benchmark. |
| Migration cost | GLBs/data definitions reusable; TypeScript gameplay, React/CSS UI, touch behavior, save compatibility and Capacitor plugins need porting/replacement. Native speed is plausible, **not proven here**. | Preserves implemented gameplay and saves; lowest near-term delivery cost. |

**$0 engine does not mean $0 store distribution.** Apple normally requires **$99/year** membership for App Store release (eligible fee waivers exist), plus Mac access. Google Play normally charges **$25 once**. [16] These affect either stack. If no recurring payment is acceptable, prioritize Android testing + Web and defer paid iOS store distribution.

## Non-destructive Godot tiny validation plan

Proposed only; no engine project or builds were created. Timebox: **two working days after GLBs are ready**, using one pinned stable Godot 4.x release with matching templates, GDScript and no paid addons.

1. Create **experiments/godot-camp-slice/** with its own project.godot, scenes/, scripts/, assets/, licenses/ and exports/. Keep generated .godot/build files out of version control when implementing. Copy pilot exports; no shared-asset regeneration. Preserve src/, public/, android/, ios/, package files and current saves. Package ID **com.promisepath.godotslice** differs from current com.promisepath.next.
2. One Camp.tscn: small uneven camp terrain with collision, one Abram GLB under CharacterBody3D/capsule, one tent GLB with obstacle collision, orthographic 35–45° camera and directional light. Bake NavigationRegion3D around the tent with agent-radius clearance. Start **Compatibility** for Android/Web consistency; compare Mobile on the same phone only if time remains.
3. Tap-to-move: ScreenTouch → camera ray → ground collision mask; reject UI taps and invalid/unreachable navmesh targets. Set NavigationAgent3D target; each physics tick follow its next path position using move_and_slide. Blend idle/walk through AnimationTree using actual speed. Wait for navigation-map synchronization before requesting paths. Physics collisions remain authoritative; navigation alone does not prevent penetration.
4. Export debug APK with matching templates, OpenJDK 17 and SDK packages specified by the pinned release. Install by USB/ADB on an existing **physical midrange Android**. No Play membership needed for this local test. Export only inside the experiment; never reuse the existing android/ project or uninstall the current game.
5. Record device/OS/build, render resolution and thermal conditions. Measure cold launch, median/p95 frame time, process memory after 10 minutes, draw calls, package/download size and development hours. Compare identical assets/camera/lighting with the current stack where possible. If a controlled baseline needs src/ edits, defer those to a separately authorized branch; do not claim speedup from mismatched scenes.
6. Pass gates: 20 taps, including behind the tent, route correctly; no crashes or increasing memory trend over 10 minutes; 30 FPS target with **p95 frame time ≤33.3 ms** after warm-up; no persistent clipping/input misses; slice draw/texture limits above. Export a single-thread Compatibility Web build and test Chrome/Safari when available, targeting existing **<25 MB compressed download and <8 s interaction** budgets on a recorded connection. Targets are not measured results.
7. Deliver APK, screenshots/capture and measurements in the experiment. Migrate only if import, controls and stability pass and editor/native benefits justify a separate UI/state/save/plugin port estimate. Otherwise retain Three.js/Capacitor and reuse improved GLBs. Android success does not validate iOS/Web; test both before commitment. Rollback means leaving the isolated experiment unused.

## Primary sources and limitations

Sources checked 2026-11-20; mutable plans/licenses need rechecking at asset intake. No model generation, rig export, engine benchmark or physical-device build was performed.

1. [TRELLIS repository and license](https://github.com/microsoft/TRELLIS).
2. [TripoSR repository and license](https://github.com/VAST-AI-Research/TripoSR).
3. [TripoSG repository](https://github.com/VAST-AI-Research/TripoSG), [official weights](https://huggingface.co/VAST-AI/TripoSG).
4. [InstantMesh repository](https://github.com/TencentARC/InstantMesh), [official weights](https://huggingface.co/TencentARC/InstantMesh).
5. Exact [Hunyuan3D 2.0 LICENSE](https://github.com/Tencent-Hunyuan/Hunyuan3D-2/blob/main/LICENSE) and [2.1 LICENSE](https://github.com/Tencent-Hunyuan/Hunyuan3D-2.1/blob/main/LICENSE), especially §§3–5; do not generalize to other versions.
6. [Meshy terms](https://www.meshy.ai/terms-of-use), [commercial FAQ](https://help.meshy.ai/en/articles/9992001-can-i-use-meshy-assets-commercially-license-copyright-explained), [plans](https://www.meshy.ai/pricing).
7. [Hyper3D terms](https://hyper3d.ai/legal/terms), §§2/6.2; [pricing](https://hyper3d.ai/pricing).
8. [Blender output/license FAQ](https://www.blender.org/about/license/), [Rigify manual](https://docs.blender.org/manual/en/latest/addons/rigify/index.html). Manual was search-index accessible but direct retrieval failed; output rights rely on Blender's license page.
9. [AccuRIG overview](https://www.reallusion.com/auto-rig/accurig/default.html), [export manual](https://manual.reallusion.com/AccuRig-2/2.0/09-add-motions/export.htm), [Software EULA, May 25 2026](https://www.reallusion.com/Content/EULA/AP/EULA_AP.htm), [content policy](https://www.reallusion.com/license/content.html). Free-version commercial grant remains unresolved.
10. [Adobe Mixamo FAQ](https://helpx.adobe.com/creative-cloud/faq/mixamo-faq.html).
11. [Godot license](https://godotengine.org/license/), [compliance](https://docs.godotengine.org/en/stable/about/complying_with_licenses.html).
12. Godot [3D formats](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_3d_scenes/available_formats.html), [NavigationAgent3D](https://docs.godotengine.org/en/stable/classes/class_navigationagent3d.html), [AnimationTree](https://docs.godotengine.org/en/stable/tutorials/animation/animation_tree.html).
13. [Godot renderer comparison](https://docs.godotengine.org/en/stable/tutorials/rendering/renderers.html).
14. Godot [Android export](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html), [iOS export](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_ios.html).
15. [Godot Web export, versioned 4.5 reference](https://docs.godotengine.org/en/4.5/tutorials/export/exporting_for_web.html); recheck against pinned release.
16. [Apple enrollment](https://developer.apple.com/help/account/membership/program-enrollment), [Google Play registration](https://support.google.com/googleplay/android-developer/answer/6112435/).

Research tooling: Factreach skill was read; configured executable/open-websearch were unavailable (ENOENT), so connected web search/open retrieved primary sources. Factreach update check could not run. No cloud asset upload, login, purchase or subscription was used. Only this report was written; src/ was not modified.
