# VHDL_Implementation

THis folder contains the VHDL files used to build the processor from the ground up, organized hierarchically

The file naming was done according to the level at which the file is (and as a consequence when it needs to be compiled).\
Eg: `a.a.a-GlobalConstants` will be compiled before `a.a.b-xy.vhd` and `a.b-DataPath.elements` ecc.

The folders group entities as follows:
- **a.a.a-GlobalConstants** : holds files that contain type definitions or constant values used across the whole CPU
- **a.a-DataPath.elements** : holds entities that are used throughout the whole CPU as components, such as registers or muxes
- **a.b-DataPath.executeStage** : holds entities instantiated in the execute stage (but does not contain the execute stage top level)
- **a.b-DataPath.memorySystem** : holds entities used to handle memory requests, both to the DataRAM and InstructionRAM
- **a.c-ControlUnit** : holds the CU and hazard/forward unit, everything related to the control part of the CPU
- **b.a-DataPath.stages** : holds the top level definition of each stage of the pipeline

Some entities are not put in folders