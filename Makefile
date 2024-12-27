# Compiler and flags
CC = mpicc
NVCC = nvcc
CXX = g++

# Optimization flags
CFLAGS = -mavx512f -mavx512dq -mavx512cd -fopenmp -O3 -ffast-math -march=native
CUDA_FLAGS = -arch=sm_80 -O3 --use_fast_math
MPI_FLAGS = -I${MPI_HOME}/include
INCLUDES = -I./include -I${CUDA_HOME}/include

# Libraries
LIBS = -lm -lcuda -lcudart -lmpi -lnuma -lcrypto -lssl -lpthread
LIB_DIRS = -L${CUDA_HOME}/lib64 -L${MPI_HOME}/lib

# Directories
SRC_DIR = src
BUILD_DIR = build
TEST_DIR = tests
DOC_DIR = docs
BACKUP_DIR = backup

# Source files
SRCS = $(wildcard $(SRC_DIR)/*.c)
CUDA_SRCS = $(wildcard $(SRC_DIR)/*.cu)
CPP_SRCS = $(wildcard $(SRC_DIR)/*.cpp)
ASM_SRCS = $(wildcard $(SRC_DIR)/*.asm)

# Object files
OBJS = $(SRCS:$(SRC_DIR)/%.c=$(BUILD_DIR)/%.o)
CUDA_OBJS = $(CUDA_SRCS:$(SRC_DIR)/%.cu=$(BUILD_DIR)/%.cu.o)
CPP_OBJS = $(CPP_SRCS:$(SRC_DIR)/%.cpp=$(BUILD_DIR)/%.o)
ASM_OBJS = $(ASM_SRCS:$(SRC_DIR)/%.asm=$(BUILD_DIR)/%.o)

# Executables
MAIN_EXE = quantum_simulator
TEST_EXE = run_tests

# Default target
all: dirs $(MAIN_EXE)

# Create build directories
dirs:
	@mkdir -p $(BUILD_DIR)
	@mkdir -p $(TEST_DIR)
	@mkdir -p $(BACKUP_DIR)
	@mkdir -p $(DOC_DIR)

# Main executable
$(MAIN_EXE): $(OBJS) $(CUDA_OBJS) $(CPP_OBJS) $(ASM_OBJS)
	$(CC) $(CFLAGS) $^ -o $@ $(LIB_DIRS) $(LIBS)

# Compile C files
$(BUILD_DIR)/%.o: $(SRC_DIR)/%.c
	$(CC) $(CFLAGS) $(INCLUDES) -c $< -o $@

# Compile CUDA files
$(BUILD_DIR)/%.cu.o: $(SRC_DIR)/%.cu
	$(NVCC) $(CUDA_FLAGS) $(INCLUDES) -c $< -o $@

# Compile C++ files
$(BUILD_DIR)/%.o: $(SRC_DIR)/%.cpp
	$(CXX) $(CFLAGS) $(INCLUDES) -c $< -o $@

# Compile Assembly files
$(BUILD_DIR)/%.o: $(SRC_DIR)/%.asm
	nasm -f elf64 $< -o $@

# Testing targets
test: dirs $(TEST_EXE)
	./$(TEST_EXE)

$(TEST_EXE): $(TEST_DIR)/*.c $(OBJS)
	$(CC) $(CFLAGS) $^ -o $@ $(LIB_DIRS) $(LIBS)

# Documentation
docs:
	doxygen Doxyfile

# Backup
backup:
	@tar -czf $(BACKUP_DIR)/backup-$$(date +%Y%m%d-%H%M%S).tar.gz \
		$(SRC_DIR) $(TEST_DIR) $(DOC_DIR) Makefile

# Security checks
security-check:
	cppcheck --enable=all $(SRC_DIR)
	scan-build make

# Performance profiling
profile: $(MAIN_EXE)
	perf record ./$(MAIN_EXE)
	perf report

# Clean build files
clean:
	rm -rf $(BUILD_DIR)
	rm -f $(MAIN_EXE) $(TEST_EXE)

# Deep clean (including backups and docs)
clean-all: clean
	rm -rf $(BACKUP_DIR)
	rm -rf $(DOC_DIR)

# Install dependencies
install-deps:
	@echo "Installing dependencies..."
	@apt-get update && apt-get install -y \
		build-essential \
		cuda-toolkit \
		openmpi-bin \
		libopenmpi-dev \
		libnuma-dev \
		libssl-dev \
		doxygen \
		cppcheck \
		clang-tools

# Continuous Integration targets
ci: security-check test

# Deployment targets
deploy-prod: backup ci
	@echo "Deploying to production..."
	./scripts/deploy.sh production

deploy-staging: backup ci
	@echo "Deploying to staging..."
	./scripts/deploy.sh staging

# Help target
help:
	@echo "Available targets:"
	@echo "  all            - Build main executable"
	@echo "  test           - Run tests"
	@echo "  docs           - Generate documentation"
	@echo "  backup         - Create backup"
	@echo "  security-check - Run security analysis"
	@echo "  profile        - Run performance profiling"
	@echo "  clean          - Remove build files"
	@echo "  clean-all      - Remove all generated files"
	@echo "  install-deps   - Install dependencies"
	@echo "  deploy-prod    - Deploy to production"
	@echo "  deploy-staging - Deploy to staging"

.PHONY: all dirs test docs backup security-check profile clean clean-all \
        install-deps ci deploy-prod deploy-staging help
