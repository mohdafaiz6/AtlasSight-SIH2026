# AtlasSight: AI-Powered Diabetic Retinopathy Screening & Triage Gateway
**Smart India Hackathon (SIH26038)**

AtlasSight is an end-to-end clinical AI screening system designed to detect Diabetic Retinopathy (DR) from digital fundus photographs, assess image quality, segment key retinal lesions, and generate explainable clinical reports for rapid specialist triage.

---

## Repository Structure

```text
AtlasSight-SIH2026/
├── trained_model.mat               # Recovered ResNet-18 classification pipeline & Grad-CAM weights
├── Figure_1.png                    # Training convergence and validation curves
├── figure1.pdf                     # Model training architecture and performance figure
├── training1.png                   # Training metrics visual
│
└── Novelty2_MATLAB/                # Novelty 2: Retinal Structure Segmentation & Explainability Suite (MATLAB)
    ├── README.md                   # Detailed documentation for Novelty 2 modules
    ├── run_all_atlas_sight.m       # Master 1-click execution script
    ├── test_aptos_image.m          # Multi-structure lesion segmentation (OD, Fovea, Vessels, EX, SE, MA, HE, NV)
    ├── mkg_explainability.m        # Medical Knowledge Graph (MKG) & ETDRS CSME reasoning
    ├── evaluate_referable_dr_grading.m # Referable DR clinical validation (Sensitivity >90%, Specificity >85%)
    ├── validate_lesion_segmentation_performance.m # IDRiD 7-structure benchmark plot
    ├── benchmark_pipeline_comparison.m # 4-way pipeline outperformance ablation (86% triage speedup)
    └── spotcheck_real_images.m     # Live disk spot-check on 15 real held-out patient images
```

---

## Novelty 2: Retinal Structure Segmentation & Medical Knowledge Graph (MATLAB)
*Contributed by: Ramitha Ravichandra*

The **** directory contains the complete native MATLAB implementation for:
1. **Multi-Lesion Segmentation:** Detects all 7 anatomical and pathological structures including **Neovascularization (NV)**, Microaneurysms, Hemorrhages, Hard/Soft Exudates, Retinal Vessels, and Optic Disc.
2. **Referable DR Clinical Validation:** Tested on =731$ held-out APTOS cohort achieving **91.55% Sensitivity** and **86.44% Specificity** ( = 0.955$).
3. **Medical Knowledge Graph Reasoning:** Explainable clinical logic for Macular Edema (CSME) and Proliferative DR.
4. **Clinical Triage Speedup:** Reduces retina specialist review time from 150 seconds to **21 seconds per patient (86% reduction)**.

To run the complete Novelty 2 suite in MATLAB:
```matlab
cd Novelty2_MATLAB
run_all_atlas_sight
```
For full module documentation and benchmarks, see [`Novelty2_MATLAB/README.md`](./Novelty2_MATLAB/README.md).
