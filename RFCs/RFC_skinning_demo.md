# RFC: Skeletal Skinning Demo

## What Is Skeletal Skinning?

Skeletal skinning (also called skeletal animation or vertex skinning) deforms a mesh by moving an underlying skeleton of **bones**. Instead of animating every vertex by hand, you animate a small number of bones and the mesh follows. This is how characters bend their arms, fingers curl, and tails wag in games and film.

The key idea: each vertex knows which bones affect it and by how much. When a bone moves, every vertex influenced by that bone moves proportionally.

## Core Concepts

### Bones and Joints

A skeleton is a hierarchy of bones connected at joints. Each bone has a **transform** (position, rotation, scale) relative to its parent. Moving a parent bone moves all its children — rotate a shoulder and the elbow, wrist, and fingers follow.

In this demo we use a minimal 2-bone rig:

```
Bone 0 (root)       Bone 1 (tip)
    |                    |
  bottom ----joint---- top
  (y=-1)     (y=0)    (y=+1)
```

Bone 0 controls the lower half of the mesh. Bone 1 controls the upper half. The joint between them is where bending occurs.

### Bind Pose

The **bind pose** (also called rest pose or T-pose) is the default position of the mesh before any animation. Bone transforms are authored relative to this pose. In our demo, the bind pose is both bones at identity — the mesh is a straight rectangular prism standing upright.

### Bone Weights

Each vertex stores:

- **Bone indices** — which bones influence it (e.g., bones 0 and 1)
- **Bone weights** — how much each bone contributes (e.g., 0.7 and 0.3, summing to 1.0)

Vertices near the bottom of the mesh have high weight for bone 0 and low weight for bone 1. Vertices near the top are the opposite. Vertices near the joint have roughly equal weights from both bones — this is the region that deforms smoothly when the skeleton bends.

In this demo, weights are assigned by linear interpolation along the Y axis:

```
weight_bone1 = (vertex_y + halfHeight) / height    // 0 at bottom, 1 at top
weight_bone0 = 1.0 - weight_bone1
```

### Linear Blend Skinning (LBS)

Linear blend skinning is the standard algorithm for deforming vertices. For each vertex:

1. Transform the vertex position by each influencing bone's matrix
2. Blend the results using the bone weights

```
skinnedPosition = w0 * (bone0Matrix * position) + w1 * (bone1Matrix * position)
```

The same blending applies to normals (using the inverse-transpose of the bone matrix to preserve correct lighting).

This runs in the **vertex shader** — every vertex is skinned on the GPU each frame.

### Bone Matrices

Each bone's final matrix combines two things:

1. **Inverse bind matrix** — undoes the bind pose, moving the vertex into bone-local space
2. **World transform** — the bone's current animated transform

```
finalBoneMatrix = currentWorldTransform * inverseBindMatrix
```

In this demo, both bones have identity bind poses, so the inverse bind matrix is also identity. The final matrix for each bone is just its current world transform:

- Bone 0: identity (the lower half stays fixed)
- Bone 1: rotation around the joint on the Z axis by the bend angle

## Limitations of Linear Blend Skinning

LBS is simple and fast but has known artifacts:

- **Candy-wrapper collapse** — twisting a bone 180° causes the mesh to collapse to zero volume at the joint
- **Volume loss** — bending a joint compresses the mesh on the inside of the bend

More advanced techniques (dual quaternion skinning, blend shapes, corrective shapes) address these, but LBS is the industry baseline and sufficient for most cases.

## Data Flow in the Demo

```
CPU (per frame):                         GPU (per vertex):
                                         
  bendAngle                              SkinnedVertex
      |                                    - position
      v                                    - normal
  computeBoneMatrices()                    - boneIndices
      |                                    - boneWeights
      v                                        |
  BoneMatricesData                             v
    - bones[2]          --buffer-->      vertex shader:
    - boneNormals[2]                       skinned = w0*(bone0*pos) + w1*(bone1*pos)
                                               |
  SkinningUniforms      --buffer-->            v
    - viewProjection                     fragment shader:
    - modelMatrix                          diffuse + specular lighting
    - cameraPosition                           |
                                               v
                                           final pixel color
```

## References

- "Real-Time Rendering" (Akenine-Möller et al.) — Chapter 4.10, Vertex Blending
- "Game Engine Architecture" (Gregory) — Chapter 12, Animation Systems
- GPU Gems 3, Chapter 2: Skinning with Dual Quaternions
